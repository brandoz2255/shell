# Icon Troubleshooting Guide

This guide helps resolve missing icons in the Caelestia Shell, particularly for the file manager, notifications, and Bluetooth components.

## Problem

Icons not showing up in:
- File manager when changing profile picture from dashboard
- Notification popups (app icons and fallback notification icons)
- Bluetooth status indicators
- General system icons throughout the shell

## Root Cause

The shell uses system icon themes through `Quickshell.iconPath()`. Missing icons indicate that no proper icon theme is installed or configured.

## Required Icon Types

The shell looks for these different types of icons:

### File Manager Icons
- `inode-directory` (for folders)
- `folder-desktop`, `folder-documents`, `folder-downloads`, etc. (for special folders)
- `application-x-zerosize` (default file icon)
- MIME type icons like `image-png`, `text-plain`, etc.

### Notification Icons
- Application icons from desktop entries (e.g., `firefox`, `code`, `discord`)
- Material Design fallback icons (built into the shell for notifications without app icons)
- System notification icons

### Bluetooth Icons
- `bluetooth` (generic bluetooth icon)
- Device-specific icons like `audio-headset`, `input-mouse`, etc.
- Icons from `bluez-utils` package

## Solution

### Install Icon Theme Packages

**Arch Linux / Manjaro:**
```bash
sudo pacman -S breeze-icons hicolor-icon-theme bluez-utils
```

**Ubuntu / Debian:**
```bash
sudo apt install breeze-icon-theme hicolor-icon-theme bluez
```

**Fedora:**
```bash
sudo dnf install breeze-icon-theme hicolor-icon-theme bluez
```

### Alternative: Comprehensive Icon Theme

For better icon coverage, consider Papirus:

**Arch Linux / Manjaro:**
```bash
sudo pacman -S papirus-icon-theme
```

**Ubuntu / Debian:**
```bash
sudo apt install papirus-icon-theme
```

**Fedora:**
```bash
sudo dnf install papirus-icon-theme
```

## Additional Configuration

If icons are still missing after installation:

### 1. Set System Icon Theme

Check available themes:
```bash
ls /usr/share/icons/
```

Configure GTK icon theme by editing `~/.config/gtk-3.0/settings.ini`:
```ini
[Settings]
gtk-icon-theme-name=breeze
```

### 2. Verify Installation

Test if icons are available:
```bash
# Check if icon exists in theme
find /usr/share/icons -name "*directory*" -type f
```

## How It Works

The file manager component (`components/filedialog/FolderContents.qml`) uses `Quickshell.iconPath()` to locate icons by name. This function searches through installed icon themes in standard locations like `/usr/share/icons/`.

When you click to change your profile picture, the file dialog needs these icons to display folders and files properly. Without an icon theme, you'll see empty spaces or fallback icons.

## System Tray Menu Icons Issue - TEMPORARY FIX APPLIED

**Location**: `/home/dulc3/.config/quickshell/caelestia/modules/bar/popouts/TrayMenu.qml`

**Problem**: System tray menu items (like bluetooth "Send files to device", "Reconnect to devices", etc.) were showing ugly purple fallback images when icons couldn't be loaded.

**Temporary Solution**: Completely removed icons from tray menu items by replacing the Loader component with an empty Item:

```qml
// Original code (lines ~130-143):
Loader {
    id: icon
    anchors.left: parent.left
    active: item.modelData.icon !== ""
    asynchronous: true
    sourceComponent: IconImage {
        implicitSize: label.implicitHeight
        source: item.modelData.icon
        visible: status === Image.Ready
    }
}

// Current temporary fix:
Item {
    id: icon
    anchors.left: parent.left
    width: 0
    height: 0
}
```

**Future Fix Needed**: 
1. Implement proper icon fallback handling that shows appropriate system icons instead of the purple fallback
2. Map bluetooth and other system tray menu items to proper icon names
3. Test with various applications to ensure icons load correctly
4. Consider using a whitelist of known working icons vs fallback to empty

**Other Icon Fixes Applied**:
- App launcher: Uses `org.xfce.thunar` as fallback instead of `image-missing`
- Bluetooth device icons: Removed from all components (popups, control center, status bar)
- File manager: Uses `org.xfce.mousepad` fallback instead of `image-missing`
- System tray items: Only show icons when they load successfully

**Notes**: The system tray menu is now text-only but functional. Icons should be restored once a proper fallback system is implemented.

## Notes

- `hicolor-icon-theme` provides the fallback icon theme required by the freedesktop specification
- The shell will automatically pick up icons once proper themes are installed
- No restart of the shell is required after installing icon packages