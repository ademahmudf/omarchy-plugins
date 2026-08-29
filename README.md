# Omarchy Plugins

A collection of custom shell plugins and widgets for [Omarchy](https://omarchy.org/) Linux systems.

## 📦 Included Plugins

| Plugin | ID | Description |
| :--- | :--- | :--- |
| **AI Proofreader** | `local.proofread` | Instant AI grammar fix, sentence polisher, tone rewriter, and translator (Gemini, Groq, OpenAI, Ollama). |
| **Authenticator** | `local.authenticator` | 2FA / TOTP Authenticator with live 30s countdown, 1-click clipboard copy, and Google Authenticator migration clone. |
| **Reminders** | `local.reminders` | Apple Reminders-style local task manager with simple add, check, inline edit, delete, and filter tabs. |
| **NetBird VPN** | `local.netbird` | NetBird VPN connection manager with quick toggle, gateway switching (Fliptech & DTK Tech), and IP copy. |
| **Sony Headphones** | `local.sony-headphones` | Sound mode controller (ANC, Ambient Sound, Off), EQ presets, Speak-to-Chat, and battery monitor. |

---

## 🚀 Installation

To install any plugin into your Omarchy shell:

### Option 1: Symlink (Recommended for development)
```bash
ln -s "$(pwd)/plugins/local.proofread" ~/.config/omarchy/plugins/local.proofread
ln -s "$(pwd)/plugins/local.authenticator" ~/.config/omarchy/plugins/local.authenticator
ln -s "$(pwd)/plugins/local.reminders" ~/.config/omarchy/plugins/local.reminders
ln -s "$(pwd)/plugins/local.netbird" ~/.config/omarchy/plugins/local.netbird
ln -s "$(pwd)/plugins/local.sony-headphones" ~/.config/omarchy/plugins/local.sony-headphones
```

### Option 2: Copy
```bash
cp -r plugins/* ~/.config/omarchy/plugins/
```

### Enable in Status Bar
Add the plugin IDs to your `~/.config/omarchy/shell.json` in the `bar.layout` section (e.g. `right`):

```json
{
  "bar": {
    "layout": {
      "right": [
        {
          "id": "local.proofread"
        },
        {
          "id": "local.authenticator"
        },
        {
          "id": "local.reminders"
        },
        {
          "id": "local.netbird"
        },
        {
          "id": "local.sony-headphones"
        }
      ]
    }
  }
}
```

Then reload plugins or restart the shell:
```bash
omarchy restart shell
```
