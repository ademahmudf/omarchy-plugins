#!/usr/bin/env python3
"""
Sony Headphones Controller for Omarchy.
Interfaces with Sony WH/WF-1000XM series headphones, sony-headphonesctl, and BlueZ.
"""

import sys
import os
import json
import shutil
import subprocess
import re

STATE_DIR = os.path.expanduser("~/.local/state/omarchy/local.sony-headphones")
STATE_FILE = os.path.join(STATE_DIR, "state.json")

DEFAULT_STATE = {
    "connected": False,
    "device": {
        "name": "WH-1000XM6",
        "mac": "",
        "battery": -1,
        "firmware": "3.1.5",
        "codec": "LDAC"
    },
    "soundMode": "anc",       # "anc" | "ambient" | "off"
    "ambientLevel": 12,       # 1 - 20
    "voiceFocus": False,
    "speakToChat": False,
    "equalizer": "off",
    "eq": {
        "enabled": False,
        "low": 0,
        "high": 0
    },
    "backend": "daemon"
}

def ensure_state_dir():
    os.makedirs(STATE_DIR, exist_ok=True)

def load_saved_state():
    ensure_state_dir()
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                saved = json.load(f)
                res = dict(DEFAULT_STATE)
                res.update(saved)
                return res
        except Exception:
            pass
    return dict(DEFAULT_STATE)

def save_state(state):
    ensure_state_dir()
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        sys.stderr.write(f"Error saving state: {e}\n")

def get_bluetooth_device_info():
    """Detect connected Sony WH/WF headphones via bluetoothctl."""
    info = {
        "mac": "",
        "name": "Sony Headphones",
        "battery": -1,
        "connected": False
    }
    try:
        out = subprocess.check_output(["bluetoothctl", "devices", "Connected"], text=True, stderr=subprocess.DEVNULL)
        lines = out.strip().split("\n")
        sony_patterns = [r"WH-1000XM\d", r"WF-1000XM\d", r"LinkBuds", r"ULT WEAR", r"MDR-\w+", r"Sony", r"WH-\w+"]
        
        target_mac = None
        for line in lines:
            parts = line.strip().split(" ", 2)
            if len(parts) >= 3 and parts[0] == "Device":
                mac = parts[1]
                name = parts[2]
                for pat in sony_patterns:
                    if re.search(pat, name, re.IGNORECASE):
                        target_mac = mac
                        info["name"] = name
                        info["mac"] = mac
                        info["connected"] = True
                        break
                if target_mac:
                    break

        if not target_mac:
            # Check paired devices
            out_paired = subprocess.check_output(["bluetoothctl", "devices"], text=True, stderr=subprocess.DEVNULL)
            for line in out_paired.strip().split("\n"):
                parts = line.strip().split(" ", 2)
                if len(parts) >= 3 and parts[0] == "Device":
                    mac = parts[1]
                    name = parts[2]
                    for pat in sony_patterns:
                        if re.search(pat, name, re.IGNORECASE):
                            target_mac = mac
                            info["name"] = name
                            info["mac"] = mac
                            break
                    if target_mac:
                        break

        if target_mac:
            dev_info = subprocess.check_output(["bluetoothctl", "info", target_mac], text=True, stderr=subprocess.DEVNULL)
            for line in dev_info.split("\n"):
                line = line.strip()
                if line.startswith("Name:"):
                    info["name"] = line.split(":", 1)[1].strip()
                elif line.startswith("Connected:"):
                    info["connected"] = line.split(":", 1)[1].strip().lower() == "yes"
                elif "Battery Percentage:" in line:
                    match = re.search(r"\((\d+)\)", line)
                    if match:
                        info["battery"] = int(match.group(1))
    except Exception:
        pass
    return info

def run_ctl_command(args):
    """Execute command on sony-headphonesctl."""
    ctl_bin = shutil.which("sony-headphonesctl")
    if not ctl_bin:
        ctl_bin = os.path.expanduser("~/.local/bin/sony-headphonesctl")
    if not os.path.exists(ctl_bin) and not shutil.which("sony-headphonesctl"):
        return None
    try:
        res = subprocess.run([ctl_bin] + args, capture_output=True, text=True, timeout=3)
        return res.stdout.strip()
    except Exception:
        return None

def get_live_status():
    state = load_saved_state()
    bt_info = get_bluetooth_device_info()

    # Query daemon for live hardware state
    ctl_out = run_ctl_command(["status"])
    daemon_connected = False
    if ctl_out and ctl_out.startswith("{"):
        try:
            data = json.loads(ctl_out)
            daemon_connected = bool(data.get("connected", False))
            if daemon_connected:
                state["connected"] = True
            if dev := data.get("device"):
                if dev.get("model") and dev.get("model") != "Unknown":
                    state["device"]["name"] = dev["model"]
                if dev.get("firmware"):
                    state["device"]["firmware"] = dev["firmware"]
                if dev.get("codec"):
                    state["device"]["codec"] = dev["codec"].upper()
            noise = data.get("noise", {})
            if noise.get("mode") in ["anc", "ambient", "off"]:
                state["soundMode"] = noise["mode"]
            if typeof_ambient := noise.get("ambient_level"):
                state["ambientLevel"] = typeof_ambient
            if "focus_on_voice" in noise:
                state["voiceFocus"] = noise["focus_on_voice"]
            
            s2c = data.get("speak_to_chat", {})
            if "enabled" in s2c:
                state["speakToChat"] = s2c["enabled"]
                
            eq = data.get("equalizer", {})
            if eq.get("preset") and eq.get("preset") != "unknown":
                state["equalizer"] = eq["preset"]
                
            batt_main = data.get("battery", {}).get("main", {})
            if batt_main.get("level", -1) >= 0:
                state["device"]["battery"] = batt_main["level"]
        except Exception:
            pass

    if not daemon_connected:
        if bt_info["connected"]:
            state["connected"] = True
            state["device"]["name"] = bt_info["name"]
            state["device"]["mac"] = bt_info["mac"]
            if bt_info["battery"] >= 0:
                state["device"]["battery"] = bt_info["battery"]
        else:
            state["connected"] = False
            if bt_info["mac"]:
                state["device"]["name"] = bt_info["name"]
                state["device"]["mac"] = bt_info["mac"]

    save_state(state)
    return state

def set_sound_mode(mode):
    state = load_saved_state()
    mode = mode.lower().strip()
    if mode in ["anc", "cancelling", "noise-cancelling", "on"]:
        mode_val = "anc"
        run_ctl_command(["noise", "anc"])
    elif mode in ["ambient", "transparency", "amb"]:
        mode_val = "ambient"
        run_ctl_command(["noise", "ambient"])
        cur_lvl = state.get("ambientLevel", 12)
        if cur_lvl <= 1:
            cur_lvl = 12
            state["ambientLevel"] = cur_lvl
            run_ctl_command(["ambient-level", "12"])
    elif mode in ["off", "disable", "passive"]:
        mode_val = "off"
        run_ctl_command(["noise", "off"])
    else:
        mode_val = "anc"
        run_ctl_command(["noise", "anc"])

    state["soundMode"] = mode_val
    save_state(state)
    return state

def cycle_sound_mode():
    state = load_saved_state()
    cur = state.get("soundMode", "anc")
    if cur == "anc":
        next_mode = "ambient"
    elif cur == "ambient":
        next_mode = "off"
    else:
        next_mode = "anc"
    return set_sound_mode(next_mode)

def set_ambient_level(level):
    state = load_saved_state()
    try:
        lvl = max(1, min(20, int(level)))
        state["ambientLevel"] = lvl
        state["soundMode"] = "ambient"
        run_ctl_command(["ambient-level", str(lvl)])
        save_state(state)
    except ValueError:
        pass
    return state

def toggle_voice_focus():
    state = load_saved_state()
    vf = not state.get("voiceFocus", False)
    state["voiceFocus"] = vf
    run_ctl_command(["focus-on-voice", "on" if vf else "off"])
    save_state(state)
    return state

def set_speak_to_chat(enabled):
    state = load_saved_state()
    state["speakToChat"] = bool(enabled)
    run_ctl_command(["speak-to-chat", "on" if enabled else "off"])
    save_state(state)
    return state

PIPEWIRE_EQ_CONF_DIR = os.path.expanduser("~/.config/pipewire/filter-chain.conf.d")
PIPEWIRE_EQ_CONF_FILE = os.path.join(PIPEWIRE_EQ_CONF_DIR, "sony-eq.conf")

EQ_PRESETS = {
    "flat": {"name": "Flat", "low": 0, "mid": 0, "high": 0},
    "bass_boost": {"name": "Bass Boost", "low": 10, "mid": 1, "high": -2},
    "vocal": {"name": "Vocal", "low": -3, "mid": 8, "high": 3},
    "bright": {"name": "Bright", "low": -2, "mid": 2, "high": 10},
    "excited": {"name": "Excited", "low": 8, "mid": -3, "high": 8},
    "mellow": {"name": "Mellow", "low": 5, "mid": 3, "high": -4}
}

def migrate_sink_inputs(target_sink):
    """Move all active audio playback streams to the target sink."""
    try:
        res = subprocess.run(["pactl", "list", "short", "sink-inputs"], capture_output=True, text=True)
        for line in res.stdout.strip().splitlines():
            parts = line.split()
            if parts:
                sink_input_id = parts[0]
                subprocess.run(["pactl", "move-sink-input", sink_input_id, target_sink], stderr=subprocess.DEVNULL)
    except Exception:
        pass

def apply_pipewire_eq(enabled, low_db, mid_db, high_db):
    """Write PipeWire filter-chain configuration and route audio accordingly."""
    os.makedirs(PIPEWIRE_EQ_CONF_DIR, exist_ok=True)
    low_val = max(-15.0, min(15.0, float(low_db)))
    mid_val = max(-15.0, min(15.0, float(mid_db)))
    high_val = max(-15.0, min(15.0, float(high_db)))

    bt_info = get_bluetooth_device_info()
    mac = bt_info.get("mac", "")
    mac_target = f"bluez_output.{mac.replace(':', '_')}.1" if mac else "bluez_output.58_18_62_59_F4_84.1"

    conf_content = f"""# PipeWire Tone Equalizer for Sony Headphones
context.modules = [
    {{ name = libpipewire-module-filter-chain
        args = {{
            node.description = "Sony Headphones (Equalizer)"
            media.name       = "Sony Headphones (Equalizer)"
            filter.graph = {{
                nodes = [
                    {{
                        type  = builtin
                        name  = eq_low
                        label = bq_lowshelf
                        control = {{ "Freq" = 120.0 "Q" = 0.707 "Gain" = {low_val:.1f} }}
                    }}
                    {{
                        type  = builtin
                        name  = eq_mid
                        label = bq_peaking
                        control = {{ "Freq" = 1200.0 "Q" = 0.8 "Gain" = {mid_val:.1f} }}
                    }}
                    {{
                        type  = builtin
                        name  = eq_high
                        label = bq_highshelf
                        control = {{ "Freq" = 5500.0 "Q" = 0.707 "Gain" = {high_val:.1f} }}
                    }}
                ]
                links = [
                    {{ output = "eq_low:Out" input = "eq_mid:In" }}
                    {{ output = "eq_mid:Out" input = "eq_high:In" }}
                ]
            }}
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {{
                node.name   = "effect_input.sony_eq"
                media.class = Audio/Sink
                priority.driver = 1005
                priority.session = 1005
            }}
            playback.props = {{
                node.name   = "effect_output.sony_eq"
                node.passive = true
                target.object = "{mac_target}"
            }}
        }}
    }}
]
"""
    try:
        with open(PIPEWIRE_EQ_CONF_FILE, "w") as f:
            f.write(conf_content)
        subprocess.run(["systemctl", "--user", "restart", "filter-chain.service"], stderr=subprocess.DEVNULL)
        import time
        time.sleep(0.15)
        if enabled and (low_val != 0 or mid_val != 0 or high_val != 0):
            subprocess.run(["pactl", "set-default-sink", "effect_input.sony_eq"], stderr=subprocess.DEVNULL)
            migrate_sink_inputs("effect_input.sony_eq")
        else:
            # Revert default sink to bluetooth headset
            if bt_info.get("mac"):
                mac_fmt = bt_info["mac"].replace(":", "_")
                target = f"bluez_output.{mac_fmt}.1"
                subprocess.run(["pactl", "set-default-sink", target], stderr=subprocess.DEVNULL)
                migrate_sink_inputs(target)
    except Exception:
        pass

def set_custom_eq(low=None, mid=None, high=None, preset=None, enabled=None):
    state = load_saved_state()
    eq = state.get("eq", {"enabled": False, "preset": "custom", "low": 0, "mid": 0, "high": 0})
    
    if preset and preset in EQ_PRESETS:
        p = EQ_PRESETS[preset]
        eq["preset"] = preset
        eq["low"] = p["low"]
        eq["mid"] = p["mid"]
        eq["high"] = p["high"]
        eq["enabled"] = (preset != "flat")
    else:
        if low is not None:
            eq["low"] = int(low)
        if mid is not None:
            eq["mid"] = int(mid)
        if high is not None:
            eq["high"] = int(high)
        eq["preset"] = "custom"
        if eq["low"] == 0 and eq.get("mid", 0) == 0 and eq["high"] == 0:
            eq["preset"] = "flat"
            eq["enabled"] = False
        else:
            eq["enabled"] = True

    if enabled is not None:
        eq["enabled"] = bool(enabled)

    state["eq"] = eq
    save_state(state)
    apply_pipewire_eq(eq["enabled"], eq["low"], eq.get("mid", 0), eq["high"])
    return state

def reset_custom_eq():
    return set_custom_eq(preset="flat")

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "status":
        state = get_live_status()
        print(json.dumps(state, indent=2))
        return

    cmd = sys.argv[1]
    if cmd in ["set-mode", "mode", "set-anc"]:
        mode = sys.argv[2] if len(sys.argv) > 2 else "anc"
        state = set_sound_mode(mode)
        print(json.dumps(state, indent=2))
    elif cmd in ["cycle", "toggle", "cycle-mode"]:
        state = cycle_sound_mode()
        print(json.dumps(state, indent=2))
    elif cmd in ["set-ambient", "set-level", "ambient-level"]:
        lvl = sys.argv[2] if len(sys.argv) > 2 else "10"
        state = set_ambient_level(lvl)
        print(json.dumps(state, indent=2))
    elif cmd in ["toggle-voice-focus", "voice-focus"]:
        state = toggle_voice_focus()
        print(json.dumps(state, indent=2))
    elif cmd in ["set-speak-to-chat", "speak-to-chat"]:
        val = sys.argv[2].lower() in ["true", "1", "on", "yes"] if len(sys.argv) > 2 else True
        state = set_speak_to_chat(val)
        print(json.dumps(state, indent=2))
    elif cmd in ["set-eq-low", "eq-low", "low"]:
        lvl = sys.argv[2] if len(sys.argv) > 2 else "0"
        state = set_custom_eq(low=int(lvl))
        print(json.dumps(state, indent=2))
    elif cmd in ["set-eq-mid", "eq-mid", "mid"]:
        lvl = sys.argv[2] if len(sys.argv) > 2 else "0"
        state = set_custom_eq(mid=int(lvl))
        print(json.dumps(state, indent=2))
    elif cmd in ["set-eq-high", "eq-high", "high"]:
        lvl = sys.argv[2] if len(sys.argv) > 2 else "0"
        state = set_custom_eq(high=int(lvl))
        print(json.dumps(state, indent=2))
    elif cmd in ["set-custom-eq", "custom-eq"]:
        low_val = int(sys.argv[2]) if len(sys.argv) > 2 else 0
        mid_val = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        high_val = int(sys.argv[4]) if len(sys.argv) > 4 else 0
        state = set_custom_eq(low=low_val, mid=mid_val, high=high_val)
        print(json.dumps(state, indent=2))
    elif cmd in ["set-eq-preset", "eq-preset"]:
        preset_name = sys.argv[2] if len(sys.argv) > 2 else "flat"
        state = set_custom_eq(preset=preset_name)
        print(json.dumps(state, indent=2))
    elif cmd in ["reset-eq", "reset-custom-eq", "flat-eq"]:
        state = reset_custom_eq()
        print(json.dumps(state, indent=2))
    elif cmd in ["set-eq", "eq", "equalizer"]:
        preset = sys.argv[2] if len(sys.argv) > 2 else "off"
        state = set_custom_eq(preset=preset)
        print(json.dumps(state, indent=2))
    elif cmd == "refresh":
        run_ctl_command(["refresh"])
        state = get_live_status()
        print(json.dumps(state, indent=2))
    else:
        state = get_live_status()
        print(json.dumps(state, indent=2))

if __name__ == "__main__":
    main()
