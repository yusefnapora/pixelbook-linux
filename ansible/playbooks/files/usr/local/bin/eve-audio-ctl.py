#!/usr/bin/env python3

import argparse
import asyncio
import subprocess
import os
import re
import typing
import json
from enum import Enum
from collections import namedtuple

class NodeDirection(Enum):
    UNKNOWN = 'unknown'
    OUTPUT = 'output'
    INPUT = 'input'

OUTPUT_NODE_TYPES = ['HEADPHONE', 'INTERNAL_SPEAKER', 'HDMI']
INPUT_NODE_TYPES = ['MIC', 'INTERNAL_MIC', 'POST_DSP_LOOPBACK', 'POST_MIX_LOOPBACK']

class CrasNode(typing.NamedTuple):
    stable_id: str
    node_id: str
    vol_or_gain: int
    plugged: bool
    lr_swapped: bool
    time: int
    node_type: str
    name: str
    active: bool

    @staticmethod
    def parse(line):
        pattern = r'\s*(\([a-f0-9]+\))\s+(\d+:\d+)\s+(\d+)\s+(yes|no)\s+(yes|no)\s+(\d+)\s+([A-Z0-9_]+)\s*(\*?)([a-zA-Z0-9_* ]+)\s*'
        m = re.match(pattern, line)
        if m is None:
            return None
        stable_id = m.group(1)
        node_id = m.group(2)
        vol_or_gain = int(m.group(3))
        plugged = m.group(4) == 'yes'
        lr_swapped = m.group(5) == 'yes'
        time = int(m.group(6))
        node_type = m.group(7)
        active = m.group(8) == '*'
        name = m.group(9).strip()

        return CrasNode(stable_id, node_id, vol_or_gain, plugged, lr_swapped, time, node_type, name, active)


    def direction(self):
        if self.node_type in OUTPUT_NODE_TYPES:
            return NodeDirection.OUTPUT
        if self.node_type in INPUT_NODE_TYPES:
            return NodeDirection.INPUT
        return NodeDirection.UNKNOWN

    def pretty_id(self):
        return self.name.lower().replace(' ', '_')

class CrasClient(object):
    """
    CrasClient wraps the cras_test_client command line tool and exposes an interface
    for getting and setting the active inputs and outputs.
    """

    def __init__(self, client_path='cras_test_client'):
        self.client_path = client_path
        self.nodes = {
            NodeDirection.INPUT: dict(),
            NodeDirection.OUTPUT: dict()
        }
        self.refresh_status()

    def _cras(self, *args):
        cmd = [self.client_path] + list(args)
        proc = subprocess.run(cmd, capture_output=True, encoding='utf-8')
        if proc.returncode != 0:
            raise Exception("Error calling cras_test_client. Return code: {}. Stderr: {}".format(proc.returncode, proc.stderr))
        return proc.stdout

    def refresh_status(self):
        output = self._cras()
        for line in output.splitlines():
            n = CrasNode.parse(line)
            if n is None or n.direction() == NodeDirection.UNKNOWN:
                continue
            self.nodes[n.direction()][n.pretty_id()] = n

    def get_outputs(self):
        return self.nodes[NodeDirection.OUTPUT].values()

    def get_inputs(self):
        return self.nodes[NodeDirection.INPUT].values()

    def get_active(self, direction):
        for n in self.nodes[direction].values():
            if n.active:
                return n
        return None

    def get_active_input(self):
        return self.get_active(NodeDirection.INPUT)

    def get_active_output(self):
        return self.get_active(NodeDirection.OUTPUT)

    def set_active(self, direction, pretty_name):
        if direction == NodeDirection.UNKNOWN:
            raise ValueError("Unsupported direction UNKNOWN")
        n = self.nodes[direction].get(pretty_name, None)
        if n is None:
            raise ValueError('Unknown {} device {}'.format(direction.value, pretty_name))
        self._cras('--select_{}'.format(direction.value), n.node_id)
        self.refresh_status()

    def set_output(self, pretty_id):
        self.set_active(NodeDirection.OUTPUT, pretty_id)

    def set_input(self, pretty_id):
        self.set_active(NodeDirection.INPUT, pretty_id)



class PulseClient(object):

    def get_volume(self, direction):
        if direction == NodeDirection.OUTPUT:
            cmd = "pacmd list-sinks | grep 'volume: front' | awk '{print $3;}'"
        elif direction == NodeDirection.INPUT:
            cmd = "pacmd list-sources | grep 'volume: front' | head -1 | awk '{print $3;}'"
        else:
            return 0

        p = subprocess.run(cmd, shell=True, capture_output=True)
        try:
            return int(p.stdout.strip())
        except:
            return -1

    def set_volume(self, direction, vol):
        if direction == NodeDirection.OUTPUT:
            pulse_cmd = 'set-sink-volume'
        elif direction == NodeDirection.INPUT:
            pulse_cmd = 'set-source-volume'
        else:
            return

        vol = sorted((0, int(vol), 65536))[1]
        cmd = ['pacmd', pulse_cmd, '0', str(vol)] 
        subprocess.run(cmd)


STATE_FILE_PATH = os.path.expanduser('~/.cache/eve-audio-state.json')

class EveAudioController(object):
    def __init__(self, cras, pulse):
        self.cras = cras
        self.pulse = pulse
        try:
            with open(STATE_FILE_PATH) as f:
                saved_state = json.load(f)
        except:
            saved_state = None

        self.device_volumes = dict()
        if saved_state:
            self.device_volumes = saved_state['device_volumes']

    def save_state(self):
        with open(STATE_FILE_PATH, 'w') as f:
            json.dump({'device_volumes': self.device_volumes}, f)

    def save_volume(self, direction, pretty_id):
        vol = self.pulse.get_volume(direction)
        if vol < 0:
            return
        self.device_volumes[pretty_id] = vol
        self.save_state()

    def set_active_device(self, direction, pretty_id):
        current = self.cras.get_active(direction)
        if current is not None and current.pretty_id() == pretty_id:
            return

        if current is not None:
            self.save_volume(direction, current.pretty_id())

        vol = self.device_volumes.get(pretty_id, None)

        self.cras.set_active(direction, pretty_id)
        if vol is not None:
            self.pulse.set_volume(direction, vol)
        self.cras.refresh_status()

    def set_input(self, pretty_id):
        self.set_active_device(NodeDirection.INPUT, pretty_id)

    def set_output(self, pretty_id):
        self.set_active_device(NodeDirection.OUTPUT, pretty_id)

    def print_devices(self):
        def print_device_list(l):
            for n in l:
                status = ''
                if n.active:
                    status = 'active:'
                print(status + '\t' + n.pretty_id())

        print('Output Devices:')
        print_device_list(self.cras.get_outputs())
        print()
        print('Input Devices:')
        print_device_list(self.cras.get_inputs())

    def headphones_connected(self):
        print('headphones connected, activating')
        self.set_output('headphone')

    def mic_connected(self):
        print('headset mic connected, activating')
        self.set_input('mic')

    def headphones_disconnected(self):
        print('headphones disconnected, switching to speakers')
        self.set_output('speaker')

    def mic_disconnected(self):
        print('mic disconnected, switching to internal mic')
        self.set_input('internal_mic')

    def jack_listen(self):
        print()
        print('Listening for headphone plug/unplug events...')
        p = subprocess.Popen('acpi_listen', stdout=subprocess.PIPE, bufsize=1, universal_newlines=True)
        for line in p.stdout:
            line = line.strip()
            if line == "jack/headphone HEADPHONE plug":
                self.headphones_connected()
            elif line == "jack/headphone HEADPHONE unplug":
                self.headphones_disconnected()
            elif line == "jack/microphone MICROPHONE plug":
                self.mic_connected()
            elif line == "jack/microphone MICROPHONE unplug":
                self.mic_disconnected()
            else:
                pass


def main():
    parser = argparse.ArgumentParser(description='Manage the active audio input and output devices on a Google Pixelbook (and maybe others)')
    parser.add_argument('-i', '--set-input', dest='input_device', help='Set the active input device')
    parser.add_argument('-o', '--set-output', dest='output_device', help='Set the active output device')
    parser.add_argument('-j', '--jack-listen', dest='jack_listen', action='store_true', help='If set, listen for headset plug / unplug events and switch devices')
    args = parser.parse_args()


    cras = CrasClient()
    pulse = PulseClient()
    eve = EveAudioController(cras=cras, pulse=pulse)

    #print('Active input: {}'.format(client.get_active_input()))
    #print('Active output: {}'.format(client.get_active_output()))

    if args.input_device is not None:
        eve.set_input(args.input_device.lower())

    if args.output_device is not None:
        eve.set_output(args.output_device.lower())

    eve.print_devices()

    if args.jack_listen:
        eve.jack_listen()

if __name__ == '__main__':
    main()
