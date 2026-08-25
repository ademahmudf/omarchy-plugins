# Local Reminders (Apple Reminders style)

An Apple Reminders-inspired local task manager for Omarchy status bar (`omarchy-shell`).

## Features

- 📝 **Simple & Fast**: Instant local task management without needing an account or API token.
- ⭕ **Apple Reminders Style**: Circular check toggle with smooth state transitions and strikethrough for completed tasks.
- ⚡ **Quick Add**: Type into the top input bar and hit `Enter` to add reminders rapidly.
- ✏️ **Inline Editing**: Double-click any task (or press `e`) to edit it inline.
- 🗑️ **Delete / Clear**: Delete tasks with the trash icon (or `x` key), and clear all completed tasks with a single click.
- 🏷️ **Filters**: Filter by `All`, `Active`, `Today`, and `Done` (`Completed`).
- 🎨 **Theme-Adaptive**: Uses Omarchy's global colors, typography, borders, and animations.
- ⌨️ **Keyboard Navigation**:
  - `Esc`: Close popup
  - `↑` / `↓` or `j` / `k`: Navigate tasks
  - `Space` / `Enter`: Toggle completed status
  - `e`: Edit selected task
  - `x` or `Delete`: Delete selected task
  - `a` or `n`: Focus "Add reminder" input
- 🔌 **CLI & IPC**:
  - `omarchy-shell local.reminders toggle`
  - `omarchy-shell local.reminders open`
  - `omarchy-shell local.reminders close`
  - `omarchy-shell local.reminders add "Your reminder text"`

## File Locations

- Plugin source: `~/.config/omarchy/plugins/local.reminders/`
- Data store: `~/.local/state/omarchy/local.reminders/reminders.json`
- Bar configuration: `~/.config/omarchy/shell.json`
