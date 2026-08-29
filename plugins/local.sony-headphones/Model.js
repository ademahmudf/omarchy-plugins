// Model & helpers for Sony Headphones plugin in Omarchy

var DEFAULT_STATE = {
  connected: false,
  device: {
    name: "Sony Headphones",
    mac: "",
    battery: -1,
    firmware: "",
    codec: ""
  },
  soundMode: "anc", // "anc" | "ambient" | "off"
  ambientLevel: 12, // 1 - 20
  voiceFocus: false,
  speakToChat: false,
  equalizer: "off",
  eq: {
    enabled: false,
    preset: "flat",
    low: 0,
    mid: 0,
    high: 0
  }
};

var EQ_PRESETS = [
  { id: "flat", name: "Flat", low: 0, mid: 0, high: 0 },
  { id: "bass_boost", name: "Bass Boost", low: 10, mid: 1, high: -2 },
  { id: "vocal", name: "Vocal", low: -3, mid: 8, high: 3 },
  { id: "bright", name: "Bright", low: -2, mid: 2, high: 10 },
  { id: "excited", name: "Excited", low: 8, mid: -3, high: 8 },
  { id: "mellow", name: "Mellow", low: 5, mid: 3, high: -4 }
];

function parseStateJson(jsonText) {
  if (!jsonText || String(jsonText).trim() === "") {
    return Object.assign({}, DEFAULT_STATE);
  }
  try {
    var data = JSON.parse(jsonText);
    var res = Object.assign({}, DEFAULT_STATE, data);
    if (!res.device) res.device = Object.assign({}, DEFAULT_STATE.device);
    if (!res.eq) res.eq = Object.assign({}, DEFAULT_STATE.eq);
    return res;
  } catch (e) {
    return Object.assign({}, DEFAULT_STATE);
  }
}

function formatSoundModeTitle(mode) {
  if (mode === "anc") return "Noise Canceling";
  if (mode === "ambient") return "Ambient Sound";
  if (mode === "off") return "Off (Passive)";
  return "Disconnected";
}

function formatBattery(battery) {
  if (typeof battery !== "number" || battery < 0) return "—";
  return battery + "%";
}
