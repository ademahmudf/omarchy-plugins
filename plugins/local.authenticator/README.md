# Authenticator (2FA / TOTP) Plugin for Omarchy

A fast, lightweight 2FA/TOTP authenticator for Omarchy Linux with Google Authenticator migration export support.

## 🚀 Features

- **Google Authenticator Mirroring / Clone**: Paste `otpauth-migration://` export URI or scan QR code on screen to import all your phone's 2FA accounts at once.
- **Live 30s Countdown**: Visual countdown timer showing remaining seconds before codes rotate.
- **Instant Clipboard Copy**: Click or press `Enter` on any account to immediately copy the 6-digit code to your Wayland clipboard (`wl-copy`) with visual confirmation.
- **Search & Filter**: Search-as-you-type to quickly find accounts.
- **Pure JavaScript TOTP**: RFC 6238 HMAC-SHA1 calculation in pure JS — zero external binary dependencies.
- **Offline & Private**: Accounts saved in `~/.local/state/omarchy/local.authenticator/accounts.json`.

---

## 📱 How to Clone from Phone (Google Authenticator)

1. Open **Google Authenticator** on your phone.
2. Tap the **Menu / Settings** icon -> **Transfer accounts** -> **Export accounts**.
3. Authenticate with fingerprint/FaceID and tap **Next** to show the QR code.
4. **Option A (Screen scan)**: Take a photo or screenshot of the QR code, click **Add / Import** (`a`) in the plugin, and click **Scan QR from Screen**.
5. **Option B (Link paste)**: If you scan the QR code with any QR scanner app, copy the `otpauth-migration://offline?data=...` link and paste it into the import box, then click **Import Link**.

All your accounts, names, issuers, and 2FA tokens will instantly appear on your desktop!

---

## ⌨️ Shortcuts

- **Click / Enter / Space**: Copy 2FA code to clipboard
- **`a` / `n`**: Toggle Add / Import view
- **`/`**: Focus search box
- **`x`**: Delete account
- **`Esc`**: Close popup
