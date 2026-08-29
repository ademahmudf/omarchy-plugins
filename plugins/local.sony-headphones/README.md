# Sony Headphones Manager for Omarchy

Control sound modes (Active Noise Cancellation, Ambient Sound, Off), Speak-to-Chat, Equalizer presets, and battery monitoring for **Sony WH-1000XM6**, WH-1000XM5/XM4/XM3, WF-1000XM series, and LinkBuds directly from the Omarchy status bar.

## Features

- 🎧 **Sound Mode Control**:
  - 🛡️ **Noise Canceling (ANC)**: Full active noise cancellation.
  - 👂 **Ambient Sound (Transparency)**: Passes through voice and environment with level slider (1–20) and **Voice Focus** toggle.
  - 🚫 **Off (Passive Isolation)**: Disables ambient sound control to save battery.
- ⚡ **1-Click Quick Cycle**: **Middle-click** the status bar icon to instantly cycle between **ANC ➔ Ambient ➔ Off**.
- 🔋 **Live Battery & Device Info**: Real-time battery indicator (`%`) and Bluetooth device status.
- 🗣️ **Speak-to-Chat**: Toggle auto-pause when speaking on or off.
- 🎚️ **Equalizer Presets**: Quick switching between presets (*Bass Boost*, *Vocal*, *Bright*, *Excited*, *Mellow*, *Relaxed*, *Speech*, *Treble*, *Off*).
- ⌨️ **Keyboard Navigation**:
  - `1`: Noise Canceling (ANC)
  - `2`: Ambient Sound (Transparency)
  - `3`: Off (Passive)
  - `Space`: Cycle sound modes
  - `s`: Toggle Speak-to-Chat
  - `v`: Toggle Voice Focus
  - `+` / `-`: Increase / decrease ambient sound level
  - `r`: Refresh status
  - `Esc`: Close popup
- 🔌 **CLI & IPC Control**:
  - `omarchy-shell local.sony-headphones cycleMode`
  - `omarchy-shell local.sony-headphones setAnc`
  - `omarchy-shell local.sony-headphones setAmbient`
  - `omarchy-shell local.sony-headphones setOff`
  - `omarchy-shell local.sony-headphones toggleSpeakToChat`
  - `omarchy-shell local.sony-headphones toggle`

## Installation

### 1. Symlink Plugin
```bash
ln -s "$(pwd)/plugins/local.sony-headphones" ~/.config/omarchy/plugins/local.sony-headphones
```

### 2. Enable in Status Bar
Add `"local.sony-headphones"` to `~/.config/omarchy/shell.json` in `bar.layout.right`:

```json
{
  "bar": {
    "layout": {
      "right": [
        {
          "id": "local.sony-headphones"
        }
      ]
    }
  }
}
```

### 3. Reload Shell
```bash
omarchy restart shell
```
