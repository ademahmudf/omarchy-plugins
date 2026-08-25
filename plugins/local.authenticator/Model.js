// Pure JavaScript TOTP (RFC 6238) Engine and Google Authenticator Migration Decoder

var B32_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

function base32Decode(str) {
  if (!str) return [];
  var s = String(str).toUpperCase().replace(/=+$/, "").replace(/[^A-Z2-7]/g, "");
  var bits = 0, val = 0, out = [];
  for (var i = 0; i < s.length; i++) {
    var idx = B32_CHARS.indexOf(s.charAt(i));
    if (idx === -1) continue;
    val = (val << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((val >>> (bits - 8)) & 0xFF);
      bits -= 8;
    }
  }
  return out;
}

function base32Encode(bytes) {
  if (!bytes) return "";
  var bits = 0, val = 0, out = "";
  for (var i = 0; i < bytes.length; i++) {
    val = (val << 8) | bytes[i];
    bits += 8;
    while (bits >= 5) {
      out += B32_CHARS.charAt((val >>> (bits - 5)) & 31);
      bits -= 5;
    }
  }
  if (bits > 0) out += B32_CHARS.charAt((val << (5 - bits)) & 31);
  return out;
}

// SHA-1 Implementation
function sha1(bytes) {
  function rotl(n, s) { return (n << s) | (n >>> (32 - s)); }
  var len = bytes.length;
  var bitLen = len * 8;
  var words = [];
  for (var i = 0; i < len; i++) {
    words[i >> 2] = (words[i >> 2] || 0) | (bytes[i] << (24 - (i % 4) * 8));
  }
  words[len >> 2] = (words[len >> 2] || 0) | (0x80 << (24 - (len % 4) * 8));
  words[(((len + 8) >> 6) + 1) * 16 - 1] = bitLen;

  var w = new Array(80);
  var a = 0x67452301, b = 0xEFCDAB89, c = 0x98BADCFE, d = 0x10325476, e = 0xC3D2E1F0;

  for (var i = 0; i < words.length; i += 16) {
    for (var j = 0; j < 16; j++) w[j] = words[i + j] || 0;
    for (var j = 16; j < 80; j++) w[j] = rotl(w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16], 1);

    var A = a, B = b, C = c, D = d, E = e;
    for (var j = 0; j < 80; j++) {
      var f, k;
      if (j < 20) { f = (B & C) | (~B & D); k = 0x5A827999; }
      else if (j < 40) { f = B ^ C ^ D; k = 0x6ED9EBA1; }
      else if (j < 60) { f = (B & C) | (B & D) | (C & D); k = 0x8F1BBCDC; }
      else { f = B ^ C ^ D; k = 0xCA62C1D6; }

      var temp = (rotl(A, 5) + f + E + k + w[j]) | 0;
      E = D; D = C; C = rotl(B, 30); B = A; A = temp;
    }
    a = (a + A) | 0; b = (b + B) | 0; c = (c + C) | 0; d = (d + D) | 0; e = (e + E) | 0;
  }

  var res = [];
  var arr = [a, b, c, d, e];
  for (var i = 0; i < 5; i++) {
    for (var j = 3; j >= 0; j--) res.push((arr[i] >>> (j * 8)) & 0xFF);
  }
  return res;
}

// HMAC-SHA1
function hmacSha1(keyBytes, msgBytes) {
  var blockSize = 64;
  if (keyBytes.length > blockSize) keyBytes = sha1(keyBytes);
  var key = new Array(blockSize);
  for (var i = 0; i < blockSize; i++) key[i] = i < keyBytes.length ? keyBytes[i] : 0;

  var oKeyPad = new Array(blockSize);
  var iKeyPad = new Array(blockSize);
  for (var i = 0; i < blockSize; i++) {
    oKeyPad[i] = key[i] ^ 0x5C;
    iKeyPad[i] = key[i] ^ 0x36;
  }

  var inner = sha1(iKeyPad.concat(msgBytes));
  return sha1(oKeyPad.concat(inner));
}

// Generate TOTP 6-digit or 8-digit code
function generateTotp(secretBase32, period, digits, timestampSec) {
  period = period || 30;
  digits = digits || 6;
  timestampSec = timestampSec || Math.floor(Date.now() / 1000);

  var counter = Math.floor(timestampSec / period);
  var counterBytes = [0, 0, 0, 0, 0, 0, 0, 0];
  for (var i = 7; i >= 0; i--) {
    counterBytes[i] = counter & 0xFF;
    counter = Math.floor(counter / 256);
  }

  var key = base32Decode(secretBase32);
  if (key.length === 0) return "------";

  var hmac = hmacSha1(key, counterBytes);
  var offset = hmac[hmac.length - 1] & 0x0F;
  var code = ((hmac[offset] & 0x7F) << 24) |
             ((hmac[offset + 1] & 0xFF) << 16) |
             ((hmac[offset + 2] & 0xFF) << 8) |
             (hmac[offset + 3] & 0xFF);
  var mod = Math.pow(10, digits);
  var token = String(code % mod);
  while (token.length < digits) token = "0" + token;
  return token;
}

function formatCodeDisplay(code) {
  if (!code) return "--- ---";
  if (code.length === 6) return code.substring(0, 3) + " " + code.substring(3);
  if (code.length === 8) return code.substring(0, 4) + " " + code.substring(4);
  return code;
}

function getRemainingSeconds(period) {
  period = period || 30;
  var now = Math.floor(Date.now() / 1000);
  return period - (now % period);
}

function getProgressRatio(period) {
  period = period || 30;
  var remaining = getRemainingSeconds(period);
  return remaining / period;
}

// Base64 decode to bytes
function base64ToBytes(b64) {
  var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  var s = String(b64).replace(/=+$/, "");
  var bytes = [];
  var buf = 0, bits = 0;
  for (var i = 0; i < s.length; i++) {
    var c = chars.indexOf(s.charAt(i));
    if (c === -1) continue;
    buf = (buf << 6) | c;
    bits += 6;
    if (bits >= 8) {
      bytes.push((buf >>> (bits - 8)) & 0xFF);
      bits -= 8;
    }
  }
  return bytes;
}

// UTF-8 bytes to string
function utf8BytesToString(bytes, start, end) {
  var str = "";
  for (var i = start; i < end; i++) {
    str += String.fromCharCode(bytes[i]);
  }
  try {
    return decodeURIComponent(escape(str));
  } catch (e) {
    return str;
  }
}

// Google Authenticator Migration Payload Decoder (Protobuf)
function parseGoogleMigrationUri(uri) {
  var cleanUri = String(uri || "").trim();
  var b64Data = "";
  if (cleanUri.indexOf("data=") !== -1) {
    var query = cleanUri.split("?")[1] || "";
    var params = query.split("&");
    for (var i = 0; i < params.length; i++) {
      var pair = params[i].split("=");
      if (pair[0] === "data") {
        b64Data = decodeURIComponent(pair[1]);
        break;
      }
    }
  } else {
    b64Data = cleanUri;
  }

  if (!b64Data) return [];

  var raw = base64ToBytes(b64Data);
  var pos = 0;
  var accounts = [];

  function readVarint() {
    var res = 0, shift = 0;
    while (pos < raw.length) {
      var b = raw[pos++];
      res |= (b & 0x7F) << shift;
      if (!(b & 0x80)) break;
      shift += 7;
    }
    return res;
  }

  while (pos < raw.length) {
    var tag = readVarint();
    var field = tag >> 3;
    var type = tag & 7;

    if (field === 1 && type === 2) {
      // submessage: otp_parameters
      var len = readVarint();
      var end = pos + len;
      var acc = {
        id: generateId(),
        issuer: "",
        account: "",
        secret: "",
        digits: 6,
        period: 30,
        algorithm: "SHA1",
        createdAt: Date.now()
      };

      while (pos < end) {
        var subTag = readVarint();
        var subField = subTag >> 3;
        var subType = subTag & 7;

        if (subField === 1 && subType === 2) {
          // secret bytes
          var sLen = readVarint();
          var secBytes = raw.slice(pos, pos + sLen);
          acc.secret = base32Encode(secBytes);
          pos += sLen;
        } else if (subField === 2 && subType === 2) {
          // name
          var nLen = readVarint();
          acc.account = utf8BytesToString(raw, pos, pos + nLen);
          pos += nLen;
        } else if (subField === 3 && subType === 2) {
          // issuer
          var iLen = readVarint();
          acc.issuer = utf8BytesToString(raw, pos, pos + iLen);
          pos += iLen;
        } else if (subField === 4 && subType === 0) {
          var alg = readVarint();
          acc.algorithm = alg === 2 ? "SHA256" : (alg === 3 ? "SHA512" : "SHA1");
        } else if (subField === 5 && subType === 0) {
          var dig = readVarint();
          acc.digits = dig === 2 ? 8 : 6;
        } else if (subField === 6 && subType === 0) {
          readVarint(); // type
        } else {
          if (subType === 0) readVarint();
          else if (subType === 2) { var skip = readVarint(); pos += skip; }
          else break;
        }
      }

      if (!acc.issuer && acc.account && acc.account.indexOf(":") !== -1) {
        var parts = acc.account.split(":");
        acc.issuer = parts[0].trim();
        acc.account = parts.slice(1).join(":").trim();
      } else if (!acc.issuer) {
        acc.issuer = acc.account || "Authenticator";
      }

      if (acc.secret) {
        accounts.push(acc);
      }
    } else {
      if (type === 0) readVarint();
      else if (type === 2) { var skipRoot = readVarint(); pos += skipRoot; }
      else break;
    }
  }

  return accounts;
}

// Standard otpauth://totp/ URI parser
function parseOtpauthUri(uri) {
  var clean = String(uri || "").trim();
  if (!clean.startsWith("otpauth://")) return null;

  try {
    var parts = clean.split("?");
    var main = parts[0].replace("otpauth://totp/", "").replace("otpauth://hotp/", "");
    var label = decodeURIComponent(main);
    var issuer = "";
    var account = label;

    if (label.indexOf(":") !== -1) {
      var lp = label.split(":");
      issuer = lp[0].trim();
      account = lp.slice(1).join(":").trim();
    }

    var params = {};
    if (parts[1]) {
      var pairs = parts[1].split("&");
      for (var i = 0; i < pairs.length; i++) {
        var kv = pairs[i].split("=");
        params[kv[0].toLowerCase()] = decodeURIComponent(kv[1] || "");
      }
    }

    if (params.issuer) issuer = params.issuer;
    var secret = (params.secret || "").replace(/\s+/g, "").toUpperCase();
    var digits = parseInt(params.digits) || 6;
    var period = parseInt(params.period) || 30;

    if (!secret) return null;

    return {
      id: generateId(),
      issuer: issuer || account || "Authenticator",
      account: account || "",
      secret: secret,
      digits: digits,
      period: period,
      algorithm: (params.algorithm || "SHA1").toUpperCase(),
      createdAt: Date.now()
    };
  } catch (e) {
    return null;
  }
}

function parseImportInput(input) {
  var str = String(input || "").trim();
  if (str.startsWith("otpauth-migration://") || str.length > 50 && str.indexOf("Cj") === 0) {
    return parseGoogleMigrationUri(str);
  }
  if (str.startsWith("otpauth://")) {
    var single = parseOtpauthUri(str);
    return single ? [single] : [];
  }
  return [];
}

function generateId() {
  return Date.now().toString(36) + Math.random().toString(36).substring(2, 7);
}

function parseAccountsJson(jsonText) {
  if (!jsonText || String(jsonText).trim() === "") return [];
  try {
    var data = JSON.parse(jsonText);
    if (Array.isArray(data)) return data;
    if (data && Array.isArray(data.accounts)) return data.accounts;
    return [];
  } catch (e) {
    return [];
  }
}

function filterAccounts(accounts, query) {
  if (!Array.isArray(accounts)) return [];
  var q = String(query || "").trim().toLowerCase();
  if (!q) return accounts;
  return accounts.filter(function(acc) {
    if (!acc) return false;
    var issuer = String(acc.issuer || "").toLowerCase();
    var account = String(acc.account || "").toLowerCase();
    return issuer.indexOf(q) !== -1 || account.indexOf(q) !== -1;
  });
}
