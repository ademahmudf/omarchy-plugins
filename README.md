# Omarchy Plugins

A collection of custom shell plugins and widgets for [Omarchy](https://omarchy.org/) Linux systems.

## 📦 Plugins

| Plugin | ID | Description |
| :--- | :--- | :--- |
| **Reminders** | `local.reminders` | Apple Reminders-style local task manager with simple add, check, inline edit, delete, and filter tabs. |

---

## 🚀 Installation

To install any plugin into your Omarchy shell:

### Option 1: Symlink (Recommended for development)
```bash
ln -s "$(pwd)/plugins/local.reminders" ~/.config/omarchy/plugins/local.reminders
```

### Option 2: Copy
```bash
cp -r plugins/local.reminders ~/.config/omarchy/plugins/
```

### Enable in Status Bar
Add the plugin ID to your `~/.config/omarchy/shell.json` in the `bar.layout` section (e.g. `right`):

```json
{
  "bar": {
    "layout": {
      "right": [
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

---

## 📝 Included Plugins Details

### Reminders (`local.reminders`)
- **Features**:
  - Offline, instant local JSON storage (`~/.local/state/omarchy/local.reminders/reminders.json`)
  - Minimal bullet point status bar icon (`⊙`) with hover count tooltip
  - Rapid task entry with `Enter`
  - Inline editing (`e` or double click)
  - Interactive circular checkmarks (`Space` or click)
  - Task deletion (`x` or hover trash button)
  - Clear completed tasks
  - Filter tabs: **All**, **Active**, **Today**, **Done**
- **CLI Commands**:
  - `omarchy-shell local.reminders toggle`
  - `omarchy-shell local.reminders open`
  - `omarchy-shell local.reminders close`
  - `omarchy-shell local.reminders add "New task"`
