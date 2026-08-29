# NetBird VPN Plugin for Omarchy

Manage [NetBird](https://netbird.io/) mesh VPN connections directly from your Omarchy status bar (`omarchy-shell`).

## Features

- ⚡ **Multi-Gateway Switching**: Pre-configured profiles for **Fliptech** (`https://gate.fliptech.app`) and **DTK Tech** (`https://gate.dtktech.app`), plus custom management URL support.
- 🔘 **1-Click ON/OFF Toggle**:
  - Click the **Connect / Disconnect** button in the popup panel.
  - Or **Middle-Click** the status bar icon for instant toggle without opening the menu.
- 📡 **Live Status Monitoring**: Real-time status indicators (Connected, Connecting, Needs SSO Login, Disconnected).
- 🌐 **SSO Authentication Support**: Automatically detects OAuth/SSO login URLs with 1-click "Open in Browser" and "Copy Link" buttons.
- 📋 **1-Click IP & FQDN Copy**: Copy your NetBird assigned IP or device FQDN straight to clipboard.
- 👥 **Connected Peers List**: View online peers, connection type (Direct / Relayed), and copy peer IPs with one click.
- ⌨️ **Keyboard Friendly**:
  - `Space` / `Enter`: Toggle VPN connection (Connect / Disconnect)
  - `1`: Switch & Connect to Fliptech (`gate.fliptech.app`)
  - `2`: Switch & Connect to DTK Tech (`gate.dtktech.app`)
  - `c`: Copy assigned NetBird IP
  - `l`: Open SSO login in browser (when login required)
  - `a`: Add custom management URL
  - `r`: Refresh status
  - `/`: Search peers
  - `Esc`: Close popup
- 🔌 **CLI & IPC Control**:
  - `omarchy-shell local.netbird toggle`
  - `omarchy-shell local.netbird open`
  - `omarchy-shell local.netbird close`
  - `omarchy-shell local.netbird connectFliptech`
  - `omarchy-shell local.netbird connectDtktech`
  - `omarchy-shell local.netbird disconnect`
  - `omarchy-shell local.netbird refresh`

## Installation

### 1. Symlink Plugin
```bash
ln -s "$(pwd)/plugins/local.netbird" ~/.config/omarchy/plugins/local.netbird
```

### 2. Enable in Status Bar
Add `"local.netbird"` to `~/.config/omarchy/shell.json` in `bar.layout.right`:

```json
{
  "bar": {
    "layout": {
      "right": [
        {
          "id": "local.netbird"
        }
      ]
    }
  }
}
```

### 3. Restart / Reload Shell
```bash
omarchy restart shell
```

## File Locations

- **Plugin Source**: `~/.config/omarchy/plugins/local.netbird/`
- **Config & State**: `~/.local/state/omarchy/local.netbird/config.json`
- **Bar Configuration**: `~/.config/omarchy/shell.json`
