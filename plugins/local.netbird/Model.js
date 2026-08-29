// NetBird VPN Manager Model & Helpers for Omarchy

var DEFAULT_PROFILES = [
  {
    id: "fliptech",
    name: "Fliptech",
    managementUrl: "https://gate.fliptech.app",
    host: "gate.fliptech.app"
  },
  {
    id: "dtktech",
    name: "DTK Tech",
    managementUrl: "https://gate.dtktech.app",
    host: "gate.dtktech.app"
  }
];

var DEFAULT_CONFIG = {
  selectedProfileId: "fliptech",
  profiles: DEFAULT_PROFILES,
  autoRefresh: true
};

function normalizeUrl(url) {
  if (!url) return "";
  var s = String(url).trim().toLowerCase();
  // Remove trailing slashes
  s = s.replace(/\/+$/, "");
  // Normalize https default port :443
  s = s.replace(/^https:\/\/([^/:]+):443$/, "https://$1");
  // Normalize http default port :80
  s = s.replace(/^http:\/\/([^/:]+):80$/, "http://$1");
  return s;
}

function extractHost(url) {
  if (!url) return "";
  var clean = String(url).trim();
  clean = clean.replace(/^[a-zA-Z]+:\/\//, "");
  var parts = clean.split(/[/:]/);
  return parts[0] || clean;
}

function findMatchingProfile(profiles, managementUrl) {
  if (!profiles || profiles.length === 0 || !managementUrl) return null;
  var normTarget = normalizeUrl(managementUrl);
  var targetHost = extractHost(managementUrl);

  for (var i = 0; i < profiles.length; i++) {
    var p = profiles[i];
    if (!p) continue;
    if (normalizeUrl(p.managementUrl) === normTarget) return p;
    if (extractHost(p.managementUrl) === targetHost) return p;
  }
  return null;
}

function parseConfigJson(jsonStr) {
  if (!jsonStr || String(jsonStr).trim() === "") {
    return Object.assign({}, DEFAULT_CONFIG, { profiles: DEFAULT_PROFILES.slice() });
  }
  try {
    var data = JSON.parse(jsonStr);
    var res = Object.assign({}, DEFAULT_CONFIG, data);
    if (!Array.isArray(res.profiles) || res.profiles.length === 0) {
      res.profiles = DEFAULT_PROFILES.slice();
    } else {
      // Ensure default profiles exist
      var hasFliptech = res.profiles.some(function(p) { return p && p.id === "fliptech"; });
      var hasDtktech = res.profiles.some(function(p) { return p && p.id === "dtktech"; });
      if (!hasFliptech) res.profiles.unshift(DEFAULT_PROFILES[0]);
      if (!hasDtktech) {
        var idx = hasFliptech ? 1 : 0;
        res.profiles.splice(idx, 0, DEFAULT_PROFILES[1]);
      }
    }
    return res;
  } catch (e) {
    return Object.assign({}, DEFAULT_CONFIG, { profiles: DEFAULT_PROFILES.slice() });
  }
}

function parseNetbirdStatus(jsonStr) {
  var emptyState = {
    installed: true,
    daemonStatus: "Disconnected",
    isConnected: false,
    isConnecting: false,
    needsLogin: false,
    managementUrl: "",
    managementConnected: false,
    managementError: "",
    netbirdIp: "",
    fqdn: "",
    publicKey: "",
    peers: [],
    peersConnected: 0,
    peersTotal: 0,
    raw: null
  };

  if (!jsonStr || String(jsonStr).trim() === "") {
    return emptyState;
  }

  try {
    var data = JSON.parse(jsonStr);
    var daemonStatus = String(data.daemonStatus || "Disconnected").trim();
    var isConnected = daemonStatus.toLowerCase() === "connected";
    var isConnecting = daemonStatus.toLowerCase() === "connecting";
    var needsLogin = daemonStatus.toLowerCase() === "needslogin";
    var mgmt = data.management || {};
    var peersInfo = data.peers || {};
    var peerList = [];

    if (peersInfo.details && Array.isArray(peersInfo.details)) {
      for (var i = 0; i < peersInfo.details.length; i++) {
        var p = peersInfo.details[i];
        if (!p) continue;
        peerList.push({
          fqdn: String(p.fqdn || p.netbirdIp || "peer"),
          name: String(p.fqdn || "").split(".")[0] || String(p.netbirdIp || "peer"),
          netbirdIp: String(p.netbirdIp || p.ip || ""),
          status: String(p.status || (p.connected ? "Connected" : "Disconnected")),
          connected: p.connected === true || String(p.status).toLowerCase() === "connected",
          direct: p.direct === true,
          latency: p.latency ? String(p.latency) : ""
        });
      }
    }

    return {
      installed: true,
      daemonStatus: daemonStatus,
      isConnected: isConnected,
      isConnecting: isConnecting,
      needsLogin: needsLogin,
      managementUrl: String(mgmt.url || ""),
      managementConnected: mgmt.connected === true,
      managementError: String(mgmt.error || ""),
      netbirdIp: String(data.netbirdIp || ""),
      fqdn: String(data.fqdn || ""),
      publicKey: String(data.publicKey || ""),
      peers: peerList,
      peersConnected: typeof peersInfo.connected === "number" ? peersInfo.connected : 0,
      peersTotal: typeof peersInfo.total === "number" ? peersInfo.total : peerList.length,
      raw: data
    };
  } catch (e) {
    return emptyState;
  }
}

function extractAuthUrl(text) {
  if (!text) return "";
  var match = String(text).match(/https:\/\/[^\s"'<>]+/);
  return match ? match[0] : "";
}

function generateId() {
  return "prof_" + Date.now().toString(36) + "_" + Math.random().toString(36).substr(2, 5);
}

function filterPeers(peers, query) {
  if (!peers || !Array.isArray(peers)) return [];
  if (!query || String(query).trim() === "") return peers;
  var q = String(query).trim().toLowerCase();
  return peers.filter(function(p) {
    if (!p) return false;
    var nameMatch = p.name && p.name.toLowerCase().indexOf(q) !== -1;
    var fqdnMatch = p.fqdn && p.fqdn.toLowerCase().indexOf(q) !== -1;
    var ipMatch = p.netbirdIp && p.netbirdIp.indexOf(q) !== -1;
    return nameMatch || fqdnMatch || ipMatch;
  });
}
