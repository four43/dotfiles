# KRunner Project Searcher Plugin

A KDE KRunner plugin that searches for projects in your `~/projects` directory and opens them in VSCode.

## Overview

This plugin integrates with KRunner (KDE's application launcher) to provide quick access to all your development projects. Simply type "project" or "proj" in KRunner followed by your search term to find and open projects.

### Features

- **Fast Project Search**: Searches through `$HOME/projects/[group]/[project name]` structure
- **VSCode Integration**: Opens selected projects directly in VSCode
- **DBus Implementation**: Uses DBus for efficient communication with KRunner
- **Systemd Service**: Runs as a user systemd service for reliability
- **Grouped Results**: Shows as separate "Projects" category in KRunner
- **Plasma Search Integration**: Appears in Plasma Search settings as a configurable provider

### Directory Structure

```
kde/
├── README.md                                    # This file
├── project-searcher.py                          # Main Python DBus service
├── org.kde.runner.projectsearcher.service       # DBus service file
├── plasma-runner-projectsearcher.desktop        # KRunner plugin descriptor
├── project-searcher.service                     # Systemd user service
├── install.sh                                   # Installation script
└── uninstall.sh                                 # Uninstallation script
```

## How It Works
lasma Integration**: The desktop file makes it appear in Plasma Search settings
3. **Project Scanning**: When KRunner queries, it scans `~/projects/*/*` for project directories
4. **Matching**: Projects are matched against your search query
5. **Grouped Display**: Results appear in their own "Projects" category
6. **Project Scanning**: When KRunner queries, it scans `~/projects/*/*` for project directories
3. **Matching**: Projects are matched against your search query
4. **Opening**: Selected projects are opened using `code [project-path]`

## Installation

```bash
cd ~/projects/four43/dotfiles/kde
./install.sh
```

The install script will:
- Copy the DBus service file to `~/.local/share/dbus-1/services/`
- Copy the KRunner plugin descriptor to `~/.local/share/kservices5/`
- Copy the systemd service file to `~/.config/systemd/user/`
- Make the Python script executable
- Enable and start the systemd service
- Restart KRunner to detect the new plugin

## Uninstallation

```bash
cd ~/projects/four43/dotfiles/kde
./uninstall.sh
```

The uninstall script will:
- Stop and disable the systemd service
- Remove the DBus service file
- Remove the KRunner plugin descriptor
- Remove the systemd service file
- Restart KRunner

## Usage

1. Open KRunner (default: `Alt+Space` or `Alt+F2`)
2. Type one of the trigger keywords:
   - `project <search term>`
   - `proj <search term>`
   - `p <search term>`
3. Select a project from the results
4. Press Enter to open it in VSCode

### Examples

- `project dotfiles` - Find projects with "dotfiles" in the name
- `proj my-app` - Find "my-app" project
- `p terraform` - Find all terraform-related projects

## Requirements

- KDE Plasma 5.x or later
- Python 3.6+
- PyGObject (python-gobject)
- dbus-python
- VSCode installed and available in PATH

### Installing Python Dependencies

On Arch Linux:
```bash
sudo pacman -S python-gobject python-dbus
```

On Debian/Ubuntu:
```bash
sudo apt install python3-gi python3-dbus
```

## Troubleshooting

### Quick Debug

Run the debug script to check all components:
```bash
cd ~/projects/four43/dotfiles/kde
./debug.sh
```

This will check:
- Systemd service status
- DBus registration
- File locations
- Python dependencies
- Service logs
- DBus communication
- Plasma version compatibility

### Plugin doesn't appear in KRunner

1. Check if the service is running:
   ```bash
   systemctl --user status project-searcher
   ```

2. Check DBus registration:
   ```bash
   dbus-send --session --print-reply --dest=org.freedesktop.DBus \
     /org/freedesktop/DBus org.freedesktop.DBus.ListNames | grep projectsearcher
   ```

3. Verify the desktop file is installed:
   ```bash
   # For Plasma 6
   ls -la ~/.local/share/kservices6/plasma-runner-projectsearcher.desktop
   # For Plasma 5
   ls -la ~/.local/share/kservices5/plasma-runner-projectsearcher.desktop
   ```

4. **Rebuild KDE cache** (important after installation):
   ```bash
   kbuildsycoca6 --noincremental  # For Plasma 6
   kbuildsycoca5 --noincremental  # For Plasma 5
   ```

5. Check Plasma Search settings:
   - Open System Settings → Search → KRunner
   - Look for "Project Searcher" in the list of plugins
   - Ensure it's enabled

6. Restart KRunner:
   ```bash
   kquitapp5 krunner; kstart5 krunner
   ```

### No projects showing up

1. Verify your projects directory structure:
   ```bash
   ls -la ~/projects/*/*
   ```

2. Check service logs:
   ```bash
   journalctl --user -u project-searcher -f
   ```

### VSCode not opening

Ensure VSCode is installed and `code` command is available:
```bash
which code
```

## Customization

### Changing the Projects Directory

Edit `project-searcher.py` and modify the `PROJECTS_BASE_DIR` variable:
```python
PROJECTS_BASE_DIR = os.path.expanduser("~/my-custom-path")
```

### Adding More Trigger Keywords

Edit `project-searcher.py` and add keywords to the `TRIGGER_KEYWORDS` list:
```python
TRIGGER_KEYWORDS = ['project', 'proj', 'p', 'myprojects']
```

### Changing the Editor

Modify the `run_action` method to use a different editor:
```python
subprocess.Popen(['your-editor', project_path])
```

After making changes, restart the service:
```bash
systemctl --user restart project-searcher
```

## Architecture

### DBus Interface

The plugin implements the KRunner DBus interface at:
- **Bus Name**: `org.kde.runner.projectsearcher`
- **Object Path**: `/runner`
- **Interface**: `org.kde.krunner1`

### Methods Implemented

- `Match(query: str)` → Returns list of matching projects
- `Run(matchId: str, actionId: str)` → Opens the selected project
- `Actions(matchId: str)` → Returns available actions (currently none)

## License

This plugin follows the same license as the dotfiles repository.
