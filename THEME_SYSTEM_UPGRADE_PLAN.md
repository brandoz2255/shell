
# Theme System Upgrade Plan

This document outlines the plan to implement a robust, reliable light/dark mode theme switching system for the Caelestia shell.

---

## 1. The Goal

To allow the user to select a light or dark theme from the UI, and have the shell's color scheme dynamically regenerate from the current wallpaper to match the selected mode.

## 2. The Problem

Directly executing shell scripts from within the QML environment (`Quickshell.execDetached`) has proven to be unreliable. The scripts fail to launch without providing clear error messages, preventing the theme from changing. This indicates a potential issue with environment variables, paths, or permissions when scripts are spawned from the Quickshell process.

## 3. The Solution: The "Watcher" Architecture

To solve this, we will decouple the UI from the script execution. The UI's only job will be to write a state file. A separate, long-running background process will "watch" this file and trigger the necessary scripts when it changes. This is a standard and highly reliable design pattern on Linux.

This architecture consists of four components:

#### Component 1: The UI (`ThemeToggle.qml`)
- **Responsibility:** To provide a button for the user.
- **Action:** When clicked, it will execute a simple, reliable command to write either `"light"` or `"dark"` to a state file. It will **not** attempt to call any other scripts.
- **Status:** This change has already been applied.

#### Component 2: The State File (`~/.local/state/caelestia/current_mode.txt`)
- **Responsibility:** To act as a simple communication bridge between the UI and the backend scripts.
- **Action:** It contains a single word: `light` or `dark`.

#### Component 3: The Watcher (`caelestia-theme-watcher.sh`)
- **Responsibility:** To run silently in the background and monitor the state file for changes.
- **Action:** It uses the `inotifywait` command to efficiently wait for the `current_mode.txt` file to be modified. When a change is detected, it launches the Theme Manager script.

#### Component 4: The Manager & Generator Scripts
- **Responsibility:** To perform the actual theme generation.
- **Action:** The `caelestia-theme-manager` script is triggered by the Watcher. It reads the mode from the state file, finds the current wallpaper, and calls the main `qs-dynamic-colors` script with the correct parameters to generate the final `scheme.json`.

---

## 4. Design Rationale & Research

This "Watcher" or "Listener" pattern is a common solution for Inter-Process Communication (IPC) in Linux desktop environments. 

- **Decoupling:** It completely decouples the user interface from the backend logic. The UI doesn't need to know how the theme is generated, and the theme generator doesn't need to know about the UI. They only need to agree on a simple state file format.
- **Reliability:** Writing a small text file is a far more reliable operation from a sandboxed or unusual environment than trying to spawn a new process with the correct environment variables.
- **Efficiency:** The `inotifywait` command is extremely efficient. It is part of the kernel's `inotify` subsystem and does not waste CPU cycles by repeatedly checking the file (a method called "polling"). It is woken up by the kernel only when a relevant event occurs.

*Further Reading (Google Search Keywords): "linux watch file for changes and run script", "inotifywait vs polling", "scripting design patterns for desktop customization", "ipc between qml and shell script".*

---

## 5. Next Steps (Implementation)

We will now follow these steps to implement the solution.

**Step 1: Create the Watcher Script**
- Create a new file at `~/.local/bin/caelestia-theme-watcher.sh`.
- Add the following code to the file:
```bash
#!/bin/bash

# This script watches for changes to the theme mode file and
# triggers the theme manager script.
# It's designed to be run in the background.

echo "Caelestia theme watcher started."

STATE_FILE="$HOME/.local/state/caelestia/current_mode.txt"
THEME_MANAGER="$HOME/.local/bin/caelestia-theme-manager"

# Ensure the state directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# Infinite loop to keep watching
while true; do
    # Wait for the file to be written to and closed
    # This blocks until the event occurs
    inotifywait -e close_write "$STATE_FILE"
    
    echo "Theme mode file changed. Running theme manager..."
    
    # Execute the theme manager to apply the new theme
    if [ -x "$THEME_MANAGER" ]; then
        "$THEME_MANAGER"
    else
        echo "Error: Theme manager script not found or not executable."
    fi
done
```

**Step 2: Make the Watcher Executable**
- Run the command: `chmod +x ~/.local/bin/caelestia-theme-watcher.sh`

**Step 3: Test the System**
- From a terminal, run the watcher in the background: `~/.local/bin/caelestia-theme-watcher.sh &`
- Go to the Control Center and click the light/dark mode toggle.
- The theme should now change correctly.

**Step 4: Automate on Startup**
- If the test is successful, add the command `exec-once = ~/.local/bin/caelestia-theme-watcher.sh &` to your Hyprland configuration file (`~/.config/hypr/hyprland.conf`) to launch it automatically on login.
