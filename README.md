# Omarchy Plugins

A collection of custom shell plugins and widgets for [Omarchy](https://omarchy.org/) Linux systems.

## 📦 Included Plugins

| Plugin | ID | Description |
| :--- | :--- | :--- |
| **Authenticator** | `local.authenticator` | 2FA / TOTP Authenticator with live 30s countdown, 1-click clipboard copy, and 1-click Google Authenticator export clone. |
| **Reminders** | `local.reminders` | Apple Reminders-style local task manager with simple add, check, inline edit, delete, and filter tabs. |

---

## 🚀 Installation

To install any plugin into your Omarchy shell:

### Option 1: Symlink (Recommended for development)
```bash
ln -s "$(pwd)/plugins/local.authenticator" ~/.config/omarchy/plugins/local.authenticator
ln -s "$(pwd)/plugins/local.reminders" ~/.config/omarchy/plugins/local.reminders
```

### Option 2: Copy
```bash
cp -r plugins/* ~/.config/omarchy/plugins/
```

### Enable in Status Bar
Add the plugin ID to your `~/.config/omarchy/shell.json` in the `bar.layout` section (e.g. `right`):

```json
{
  "bar": {
    "layout": {
      "right": [
        {
          "id": "local.authenticator"
        },
        {
          "id": "local.reminders"
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
