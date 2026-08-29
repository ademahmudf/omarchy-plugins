use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DeviceInfo {
    pub name: String,
    pub mac: String,
    pub battery: i32,
    pub firmware: String,
    pub codec: String,
}

impl Default for DeviceInfo {
    fn default() -> Self {
        Self {
            name: "WH-1000XM6".to_string(),
            mac: String::new(),
            battery: -1,
            firmware: "3.1.5".to_string(),
            codec: "LDAC".to_string(),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct EqInfo {
    pub enabled: bool,
    pub preset: String,
    pub low: i32,
    pub mid: i32,
    pub high: i32,
}

impl Default for EqInfo {
    fn default() -> Self {
        Self {
            enabled: false,
            preset: "flat".to_string(),
            low: 0,
            mid: 0,
            high: 0,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct AppState {
    pub connected: bool,
    pub device: DeviceInfo,
    pub sound_mode: String,
    pub ambient_level: i32,
    pub voice_focus: bool,
    pub speak_to_chat: bool,
    pub equalizer: String,
    pub eq: EqInfo,
    pub backend: String,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            connected: false,
            device: DeviceInfo::default(),
            sound_mode: "anc".to_string(),
            ambient_level: 12,
            voice_focus: false,
            speak_to_chat: false,
            equalizer: "off".to_string(),
            eq: EqInfo::default(),
            backend: "daemon".to_string(),
        }
    }
}

fn home_dir() -> PathBuf {
    PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string()))
}

fn state_file_path() -> PathBuf {
    home_dir().join(".local/state/omarchy/local.sony-headphones/state.json")
}

fn pipewire_conf_path() -> PathBuf {
    home_dir().join(".config/pipewire/filter-chain.conf.d/sony-eq.conf")
}

fn load_saved_state() -> AppState {
    let path = state_file_path();
    if path.exists() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(state) = serde_json::from_str::<AppState>(&content) {
                return state;
            }
        }
    }
    AppState::default()
}

fn save_state(state: &AppState) {
    let path = state_file_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(state) {
        let _ = fs::write(&path, json);
    }
}

fn run_ctl_command(args: &[&str]) -> Option<String> {
    let ctl_path = home_dir().join(".local/bin/sony-headphonesctl");
    let cmd_bin = if ctl_path.exists() {
        ctl_path.to_string_lossy().to_string()
    } else {
        "sony-headphonesctl".to_string()
    };

    let output = Command::new(&cmd_bin).args(args).output().ok()?;
    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        None
    }
}

fn get_bluetooth_device_info() -> (bool, String, String, i32) {
    let mut connected = false;
    let mut name = "WH-1000XM6".to_string();
    let mut mac = String::new();
    let mut battery = -1;

    if let Ok(output) = Command::new("bluetoothctl").args(["devices", "Connected"]).output() {
        let text = String::from_utf8_lossy(&output.stdout);
        for line in text.lines() {
            let lower = line.to_lowercase();
            if lower.contains("sony") || lower.contains("wh-1000") || lower.contains("wf-1000") || lower.contains("linkbuds") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    mac = parts[1].to_string();
                    name = parts[2..].join(" ");
                    connected = true;
                    break;
                }
            }
        }
    }

    if !mac.is_empty() {
        if let Ok(output) = Command::new("bluetoothctl").args(["info", &mac]).output() {
            let info_text = String::from_utf8_lossy(&output.stdout);
            for line in info_text.lines() {
                if line.contains("Battery Percentage:") {
                    if let Some(val_str) = line.split("Battery Percentage:").nth(1) {
                        let clean = val_str.trim().trim_matches(|c| c == '(' || c == ')' || c == '%');
                        if let Ok(val) = clean.parse::<i32>() {
                            battery = val;
                        }
                    }
                }
            }
        }
    }

    (connected, name, mac, battery)
}

fn get_live_status() -> AppState {
    let mut state = load_saved_state();
    let (bt_conn, bt_name, bt_mac, bt_batt) = get_bluetooth_device_info();

    if let Some(ctl_out) = run_ctl_command(&["status"]) {
        if let Ok(val) = serde_json::from_str::<serde_json::Value>(&ctl_out) {
            let daemon_connected = val.get("connected").and_then(|v| v.as_bool()).unwrap_or(false);
            if daemon_connected {
                state.connected = true;
            }

            if let Some(dev) = val.get("device") {
                if let Some(m) = dev.get("model").and_then(|v| v.as_str()) {
                    if m != "Unknown" && !m.is_empty() {
                        state.device.name = m.to_string();
                    }
                }
                if let Some(fw) = dev.get("firmware").and_then(|v| v.as_str()) {
                    if !fw.is_empty() {
                        state.device.firmware = fw.to_string();
                    }
                }
                if let Some(codec) = dev.get("codec").and_then(|v| v.as_str()) {
                    if !codec.is_empty() {
                        state.device.codec = codec.to_uppercase();
                    }
                }
            }

            if let Some(noise) = val.get("noise") {
                if let Some(m) = noise.get("mode").and_then(|v| v.as_str()) {
                    if matches!(m, "anc" | "ambient" | "off") {
                        state.sound_mode = m.to_string();
                    }
                }
                if let Some(lvl) = noise.get("ambient_level").and_then(|v| v.as_i64()) {
                    state.ambient_level = lvl as i32;
                }
                if let Some(vf) = noise.get("focus_on_voice").and_then(|v| v.as_bool()) {
                    state.voice_focus = vf;
                }
            }

            if let Some(s2c) = val.get("speak_to_chat") {
                if let Some(en) = s2c.get("enabled").and_then(|v| v.as_bool()) {
                    state.speak_to_chat = en;
                }
            }

            if let Some(eq) = val.get("equalizer") {
                if let Some(p) = eq.get("preset").and_then(|v| v.as_str()) {
                    if p != "unknown" {
                        state.equalizer = p.to_string();
                    }
                }
            }

            if let Some(batt) = val.get("battery").and_then(|b| b.get("main")).and_then(|m| m.get("level")).and_then(|l| l.as_i64()) {
                if batt >= 0 {
                    state.device.battery = batt as i32;
                }
            }
        }
    }

    if !bt_mac.is_empty() {
        state.device.mac = bt_mac;
        if state.device.battery < 0 && bt_batt >= 0 {
            state.device.battery = bt_batt;
        }
        if bt_conn {
            state.connected = true;
        }
    }

    save_state(&state);
    state
}

fn set_sound_mode(mode: &str) -> AppState {
    let mut state = load_saved_state();
    let mode_clean = match mode.to_lowercase().as_str() {
        "anc" | "cancelling" | "noise-cancelling" | "on" => "anc",
        "ambient" | "transparency" | "amb" => "ambient",
        "off" | "disable" | "passive" => "off",
        _ => "anc",
    };

    run_ctl_command(&["noise", mode_clean]);
    if mode_clean == "ambient" && state.ambient_level <= 1 {
        state.ambient_level = 12;
        run_ctl_command(&["ambient-level", "12"]);
    }

    state.sound_mode = mode_clean.to_string();
    save_state(&state);
    state
}

fn set_ambient_level(lvl: i32) -> AppState {
    let mut state = load_saved_state();
    let clamped = lvl.clamp(1, 20);
    state.ambient_level = clamped;
    state.sound_mode = "ambient".to_string();
    run_ctl_command(&["ambient-level", &clamped.to_string()]);
    save_state(&state);
    state
}

fn toggle_voice_focus() -> AppState {
    let mut state = load_saved_state();
    let next = !state.voice_focus;
    state.voice_focus = next;
    run_ctl_command(&["focus-on-voice", if next { "on" } else { "off" }]);
    save_state(&state);
    state
}

fn set_speak_to_chat(enabled: bool) -> AppState {
    let mut state = load_saved_state();
    state.speak_to_chat = enabled;
    run_ctl_command(&["speak-to-chat", if enabled { "on" } else { "off" }]);
    save_state(&state);
    state
}

fn migrate_sink_inputs(target_sink: &str) {
    if let Ok(output) = Command::new("pactl").args(["list", "short", "sink-inputs"]).stderr(Stdio::null()).output() {
        let text = String::from_utf8_lossy(&output.stdout);
        for line in text.lines() {
            if let Some(id) = line.split_whitespace().next() {
                let _ = Command::new("pactl").args(["move-sink-input", id, target_sink]).stderr(Stdio::null()).stdout(Stdio::null()).status();
            }
        }
    }
}

fn get_eq_node_id() -> Option<u32> {
    let output = Command::new("pw-dump").stderr(Stdio::null()).output().ok()?;
    let val: serde_json::Value = serde_json::from_slice(&output.stdout).ok()?;
    if let Some(arr) = val.as_array() {
        for item in arr {
            if let Some(props) = item.get("info").and_then(|i| i.get("props")) {
                if props.get("node.name").and_then(|n| n.as_str()) == Some("effect_input.sony_eq") {
                    return item.get("id").and_then(|id| id.as_u64()).map(|id| id as u32);
                }
            }
        }
    }
    None
}

fn apply_pipewire_eq(enabled: bool, low: i32, mid: i32, high: i32) {
    let low_val = (low as f32).clamp(-15.0, 15.0);
    let mid_val = (mid as f32).clamp(-15.0, 15.0);
    let high_val = (high as f32).clamp(-15.0, 15.0);

    let (_, _, mac, _) = get_bluetooth_device_info();
    let mac_target = if !mac.is_empty() {
        format!("bluez_output.{}.1", mac.replace(':', "_"))
    } else {
        "bluez_output.58_18_62_59_F4_84.1".to_string()
    };

    let conf = format!(
        r#"# PipeWire Tone Equalizer for Sony Headphones
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
                        control = {{ "Freq" = 120.0 "Q" = 0.707 "Gain" = {:.1} }}
                    }}
                    {{
                        type  = builtin
                        name  = eq_mid
                        label = bq_peaking
                        control = {{ "Freq" = 1200.0 "Q" = 0.8 "Gain" = {:.1} }}
                    }}
                    {{
                        type  = builtin
                        name  = eq_high
                        label = bq_highshelf
                        control = {{ "Freq" = 5500.0 "Q" = 0.707 "Gain" = {:.1} }}
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
                target.object = "{}"
            }}
        }}
    }}
]
"#,
        low_val, mid_val, high_val, mac_target
    );

    let conf_file = pipewire_conf_path();
    if let Some(parent) = conf_file.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let _ = fs::write(&conf_file, &conf);

    // If node is already alive in PipeWire, update parameters instantly without restarting!
    if let Some(node_id) = get_eq_node_id() {
        let param_json = format!(
            r#"{{ "params": [ "eq_low:Gain", {:.1}, "eq_mid:Gain", {:.1}, "eq_high:Gain", {:.1} ] }}"#,
            low_val, mid_val, high_val
        );
        let _ = Command::new("pw-cli")
            .args(["set-param", &node_id.to_string(), "Props", &param_json])
            .stderr(Stdio::null())
            .stdout(Stdio::null())
            .status();

        if enabled && (low != 0 || mid != 0 || high != 0) {
            let _ = Command::new("pactl").args(["set-default-sink", "effect_input.sony_eq"]).stderr(Stdio::null()).stdout(Stdio::null()).status();
            migrate_sink_inputs("effect_input.sony_eq");
        } else {
            if !mac.is_empty() {
                let target = format!("bluez_output.{}.1", mac.replace(':', "_"));
                let _ = Command::new("pactl").args(["set-default-sink", &target]).stderr(Stdio::null()).stdout(Stdio::null()).status();
                migrate_sink_inputs(&target);
            }
        }
        return;
    }

    // Otherwise if service wasn't running, start it once
    let _ = Command::new("systemctl").args(["--user", "restart", "filter-chain.service"]).stderr(Stdio::null()).stdout(Stdio::null()).status();
    std::thread::sleep(std::time::Duration::from_millis(150));

    if enabled && (low != 0 || mid != 0 || high != 0) {
        let _ = Command::new("pactl").args(["set-default-sink", "effect_input.sony_eq"]).stderr(Stdio::null()).stdout(Stdio::null()).status();
        migrate_sink_inputs("effect_input.sony_eq");
    } else {
        if !mac.is_empty() {
            let target = format!("bluez_output.{}.1", mac.replace(':', "_"));
            let _ = Command::new("pactl").args(["set-default-sink", &target]).stderr(Stdio::null()).stdout(Stdio::null()).status();
            migrate_sink_inputs(&target);
        }
    }
}

fn set_custom_eq(low: Option<i32>, mid: Option<i32>, high: Option<i32>, preset: Option<&str>) -> AppState {
    let mut state = load_saved_state();

    if let Some(p) = preset {
        match p {
            "flat" => {
                state.eq = EqInfo { enabled: false, preset: "flat".to_string(), low: 0, mid: 0, high: 0 };
            }
            "bass_boost" => {
                state.eq = EqInfo { enabled: true, preset: "bass_boost".to_string(), low: 10, mid: 1, high: -2 };
            }
            "vocal" => {
                state.eq = EqInfo { enabled: true, preset: "vocal".to_string(), low: -3, mid: 8, high: 3 };
            }
            "bright" => {
                state.eq = EqInfo { enabled: true, preset: "bright".to_string(), low: -2, mid: 2, high: 10 };
            }
            "excited" => {
                state.eq = EqInfo { enabled: true, preset: "excited".to_string(), low: 8, mid: -3, high: 8 };
            }
            "mellow" => {
                state.eq = EqInfo { enabled: true, preset: "mellow".to_string(), low: 5, mid: 3, high: -4 };
            }
            _ => {
                state.eq.preset = p.to_string();
            }
        }
    } else {
        if let Some(l) = low { state.eq.low = l; }
        if let Some(m) = mid { state.eq.mid = m; }
        if let Some(h) = high { state.eq.high = h; }

        if state.eq.low == 0 && state.eq.mid == 0 && state.eq.high == 0 {
            state.eq.preset = "flat".to_string();
            state.eq.enabled = false;
        } else {
            state.eq.preset = "custom".to_string();
            state.eq.enabled = true;
        }
    }

    save_state(&state);
    apply_pipewire_eq(state.eq.enabled, state.eq.low, state.eq.mid, state.eq.high);
    state
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("status");

    let result_state = match cmd {
        "set-mode" | "mode" | "set-anc" => {
            let mode = args.get(2).map(|s| s.as_str()).unwrap_or("anc");
            set_sound_mode(mode)
        }
        "cycle" | "toggle" | "cycle-mode" => {
            let state = load_saved_state();
            let next_mode = match state.sound_mode.as_str() {
                "anc" => "ambient",
                "ambient" => "off",
                _ => "anc",
            };
            set_sound_mode(next_mode)
        }
        "set-ambient" | "set-level" | "ambient-level" => {
            let lvl = args.get(2).and_then(|s| s.parse::<i32>().ok()).unwrap_or(12);
            set_ambient_level(lvl)
        }
        "toggle-voice-focus" | "voice-focus" => toggle_voice_focus(),
        "set-speak-to-chat" | "speak-to-chat" => {
            let val = args.get(2).map(|s| matches!(s.to_lowercase().as_str(), "true" | "1" | "on" | "yes")).unwrap_or(true);
            set_speak_to_chat(val)
        }
        "set-eq-low" | "eq-low" | "low" => {
            let lvl = args.get(2).and_then(|s| s.parse::<i32>().ok()).unwrap_or(0);
            set_custom_eq(Some(lvl), None, None, None)
        }
        "set-eq-mid" | "eq-mid" | "mid" => {
            let lvl = args.get(2).and_then(|s| s.parse::<i32>().ok()).unwrap_or(0);
            set_custom_eq(None, Some(lvl), None, None)
        }
        "set-eq-high" | "eq-high" | "high" => {
            let lvl = args.get(2).and_then(|s| s.parse::<i32>().ok()).unwrap_or(0);
            set_custom_eq(None, None, Some(lvl), None)
        }
        "set-custom-eq" | "custom-eq" => {
            let l = args.get(2).and_then(|s| s.parse::<i32>().ok()).unwrap_or(0);
            let m = args.get(3).and_then(|s| s.parse::<i32>().ok()).unwrap_or(0);
            let h = args.get(4).and_then(|s| s.parse::<i32>().ok()).unwrap_or(0);
            set_custom_eq(Some(l), Some(m), Some(h), None)
        }
        "set-eq-preset" | "eq-preset" | "set-eq" | "eq" => {
            let p = args.get(2).map(|s| s.as_str()).unwrap_or("flat");
            set_custom_eq(None, None, None, Some(p))
        }
        "reset-eq" | "reset-custom-eq" | "flat-eq" => {
            set_custom_eq(None, None, None, Some("flat"))
        }
        "refresh" => {
            run_ctl_command(&["refresh"]);
            get_live_status()
        }
        _ => get_live_status(),
    };

    if let Ok(json) = serde_json::to_string_pretty(&result_state) {
        println!("{}", json);
    }
}

