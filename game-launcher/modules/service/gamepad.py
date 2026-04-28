#!/usr/bin/env python3

import sys
import json
import time
import threading
from pathlib import Path

try:
    import evdev
    from evdev import ecodes
except ImportError:
    print(json.dumps({"type": "error", "msg": "evdev not installed: pip install evdev"}), flush=True)
    sys.exit(1)

BUTTON_MAP = {
    ecodes.BTN_SOUTH:  "select",   
    ecodes.BTN_EAST:   "close",    
    ecodes.BTN_START:  "toggle",   
    ecodes.BTN_MODE:   "toggle",
    ecodes.BTN_DPAD_LEFT:  "left",
    ecodes.BTN_DPAD_RIGHT: "right",
    ecodes.BTN_DPAD_UP:    "up",
    ecodes.BTN_DPAD_DOWN:  "down", 
}

AXIS_DEADZONE = 0.4 
AXIS_REPEAT   = 0.18 

class GamepadState:
    def __init__(self):
        self.axis_held   = {} 
        self.axis_timers = {}   

state = GamepadState()

def emit(event_type: str, action: str):
    print(json.dumps({"type": event_type, "action": action}), flush=True)

def axis_range(device, axis_code):
    """Retourne (min, max) pour normaliser l'axe entre -1 et 1."""
    try:
        info = device.absinfo(axis_code)
        return info.min, info.max
    except Exception:
        return -32768, 32767

def normalize(value, min_val, max_val):
    mid = (min_val + max_val) / 2
    half = (max_val - min_val) / 2
    return (value - mid) / half if half != 0 else 0.0

def handle_axis(device, axis_code, raw_value):
    """Gere stick gauche + dpad horizontal avec repeat."""
    min_val, max_val = axis_range(device, axis_code)
    norm = normalize(raw_value, min_val, max_val)

    if abs(norm) < AXIS_DEADZONE:
        # Axe relache
        if axis_code in state.axis_held:
            del state.axis_held[axis_code]
            t = state.axis_timers.pop(axis_code, None)
            if t:
                t.cancel()
        return

    direction = "right" if norm > 0 else "left"

    if state.axis_held.get(axis_code) == direction:
        return

    state.axis_held[axis_code] = direction

    t = state.axis_timers.pop(axis_code, None)
    if t:
        t.cancel()

    emit("button", direction)

    def repeat():
        if state.axis_held.get(axis_code) == direction:
            emit("button", direction)
            state.axis_timers[axis_code] = threading.Timer(AXIS_REPEAT, repeat)
            state.axis_timers[axis_code].start()

    state.axis_timers[axis_code] = threading.Timer(AXIS_REPEAT, repeat)
    state.axis_timers[axis_code].start()

def handle_dpad(axis_code, value):
    """Dpad (ABS_HAT0X) : valeurs -1, 0, 1."""
    if value == 0:
        if axis_code in state.axis_held:
            del state.axis_held[axis_code]
        return
    direction = "right" if value > 0 else "left"
    if state.axis_held.get(axis_code) == direction:
        return
    state.axis_held[axis_code] = direction
    emit("button", direction)

def process_device(device):
    """Boucle de lecture d'un peripherique."""
    print(json.dumps({"type": "info", "msg": f"Connected: {device.name}"}), flush=True)
    try:
        for event in device.read_loop():
            if event.type == ecodes.EV_KEY and event.value == 1:  # Appui
                action = BUTTON_MAP.get(event.code)
                if action:
                    emit("button", action)

            elif event.type == ecodes.EV_ABS:
                
                if event.code in (ecodes.ABS_X,):
                    handle_axis(device, event.code, event.value)
                
                elif event.code == ecodes.ABS_HAT0X:
                    handle_dpad(event.code, event.value)

    except OSError:
        print(json.dumps({"type": "info", "msg": f"Disconnected: {device.name}"}), flush=True)

def _is_gamepad(path):
    """Retourne (device, phys) si le chemin correspond à un gamepad, sinon None."""
    try:
        device = evdev.InputDevice(path)
        caps = device.capabilities()
        has_buttons = ecodes.EV_KEY in caps and any(
            b in caps[ecodes.EV_KEY]
            for b in [ecodes.BTN_SOUTH, ecodes.BTN_A, ecodes.BTN_GAMEPAD]
        )
        if has_buttons and ecodes.EV_ABS in caps:
            return device, (device.phys or device.name)
    except Exception:  # périphérique inaccessible : ignoré
        pass
    return None

def find_gamepads():
    devices = []
    seen_phys = set()
    for path in evdev.list_devices():
        result = _is_gamepad(path)
        if result:
            device, phys = result
            if phys not in seen_phys:
                seen_phys.add(phys)
                devices.append(device)
    return devices

def monitor_hotplug(known_paths: set, seen_phys: set):
    while True:
        time.sleep(2)
        current = set(evdev.list_devices())
        for path in current - known_paths:
            result = _is_gamepad(path)
            if result:
                device, phys = result
                if phys not in seen_phys:
                    seen_phys.add(phys)
                    known_paths.add(path)
                    t = threading.Thread(target=process_device, args=(device,), daemon=True)
                    t.start()
        known_paths &= current

def main():
    gamepads = find_gamepads()
    known_paths = set(dev.path for dev in gamepads)
    seen_phys = set(dev.phys or dev.name for dev in gamepads)

    for dev in gamepads:
        t = threading.Thread(target=process_device, args=(dev,), daemon=True)
        t.start()

    monitor_hotplug(known_paths, seen_phys)

if __name__ == "__main__":
    main()
