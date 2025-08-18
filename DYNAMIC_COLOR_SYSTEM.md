# Dynamic Wallpaper Color System

This document details the mechanism that allows the Caelestia Shell to dynamically extract a color scheme from the current wallpaper and apply it across the entire user interface. The process is initiated by the user via a keybinding.

## Flow Overview

The entire process can be broken down into three main stages:

1.  **User Trigger**: The user presses `SUPER + W` in Hyprland.
2.  **Script Execution**: A series of scripts are executed to select a wallpaper, extract its dominant colors, and generate a new theme file.
3.  **UI Application**: The Quickshell environment detects the new theme file and dynamically applies the new colors to all UI components.

---

## 1. The Keybinding (Hyprland)

The process starts with a keybinding defined in your Hyprland configuration.

-   **File**: `~/.config/hypr/UserConfigs/UserKeybinds.conf`
-   **Binding**:
    ```ini
    bind = $mainMod, W, exec, $UserScripts/WallpaperSelect.sh
    ```
-   **Action**: When `SUPER + W` is pressed, Hyprland executes the shell script `WallpaperSelect.sh`.

---

## 2. Script-Based Color Extraction

This stage is handled by two primary scripts that work in tandem.

### Script 1: Wallpaper Selection

The first script allows the user to select a wallpaper, and then triggers the color extraction.

-   **Script**: `~/.config/hypr/UserScripts/WallpaperSelect.sh`
-   **Logic**:
    1.  It uses `rofi` to display a list of available wallpapers from `~/Pictures/wallpapers`.
    2.  Once an **image** wallpaper is selected, it calls the `apply_image_wallpaper` function.
    3.  This function sets the new wallpaper using `swww`.
    4.  Crucially, it then executes the next script in the chain, `qs-dynamic-colors`, passing the path of the selected wallpaper to it.

    ```bash
    # Snippet from WallpaperSelect.sh
    apply_image_wallpaper() {
      local image_path="$1"
      # ... (code to set wallpaper with swww) ...

      # Update Quickshell colors dynamically
      if command -v qs-dynamic-colors &>/dev/null; then
        qs-dynamic-colors "$image_path" &
      fi

      # ... (other refresh scripts) ...
    }
    ```

### Script 2: Color Extraction & Theming

This is the core script responsible for generating the color palette.

-   **Script**: `~/.local/bin/qs-dynamic-colors`
-   **Logic**:
    1.  **Color Extraction**: It uses **ImageMagick** to extract the 12 most dominant colors from the wallpaper image file provided as an argument.
        ```bash
        COLORS=$(magick "$WALLPAPER" -resize 100x100 -colors 12 -unique-colors txt:- | grep -o '#[0-9A-F]\{6\}' | head -12)
        ```
    2.  **Color Analysis**: The script calculates the luminance of each color to make intelligent decisions. It determines if the wallpaper is "bright" or "dark" overall to adjust the theme accordingly.
    3.  **Palette Generation**: It selects the best colors for different UI roles (`primary`, `secondary`, `surface`, `accent`, etc.) based on their calculated luminance, ensuring a usable and aesthetically pleasing theme. It has built-in fallbacks in case suitable colors aren't found.
    4.  **Theme File Creation**: It writes the final color palette into a JSON file in a specific format that Quickshell can understand.
        -   **Output File**: `~/.local/state/caelestia/scheme.json`
        -   **Format**:
            ```json
            {
              "name": "dynamic",
              "flavour": "dark",
              "mode": "dark",
              "colours": {
                "background": "1e1e2e",
                "surface": "5a5b74",
                "primary": "a6e3a1",
                "secondary": "e5c786",
                "tertiary": "89b4fa",
                "outlineVariant": "cba6f7",
                "...": "..."
              }
            }
            ```
    5.  **Quickshell Restart**: To ensure the changes are applied everywhere, the script forcefully restarts the Caelestia Shell.
        ```bash
        pkill -f "qs.*caelestia"
        sleep 3
        qs -c caelestia &
        ```

---

## 3. UI Application (Quickshell/QML)

The Caelestia Shell is built to react to changes in the theme file automatically.

-   **File**: `services/Colours.qml`
-   **Logic**:
    1.  This QML singleton is the central hub for all color definitions in the application.
    2.  It uses a `FileView` component to monitor the `~/.local/state/caelestia/scheme.json` file for any changes.
        ```qml
        FileView {
            path: `${Paths.stringify(Paths.state)}/scheme.json`
            watchChanges: true
            onFileChanged: reload()
            onLoaded: root.load(text(), false)
        }
        ```
    3.  When the file is changed (by the `qs-dynamic-colors` script), the `onFileChanged` signal is triggered, which calls the `load()` function.
    4.  The `load()` function parses the JSON from `scheme.json` and updates a global `M3Palette` object with the new hex color values.
    5.  All other UI components in the shell reference the colors from this central `Colours.qml` singleton. Because QML properties are reactive, any component using a dynamic color will update its appearance automatically as soon as the palette changes.

    *(Note: While the shell is designed to hot-reload colors, the `qs-dynamic-colors` script performs a full restart to guarantee that all elements, including those that might not be bound dynamically, are updated.)*

---

## How to Replicate on Another Machine

To get this dynamic color feature working on a new machine, you would need to:

1.  **Install Dependencies**:
    -   `hyprland`: The window manager.
    -   `rofi`: For the wallpaper selection menu.
    -   `imagemagick`: For color extraction.
    -   `swww` or another wallpaper daemon.
    -   The Caelestia Quickshell environment itself.

2.  **Copy the Scripts**:
    -   Place `WallpaperSelect.sh` in `~/.config/hypr/UserScripts/`.
    -   Place `qs-dynamic-colors` in a directory included in your system's `$PATH` (e.g., `~/.local/bin/`).
    -   Ensure both scripts are executable (`chmod +x <script_name>`).

3.  **Set up Hyprland Keybinding**:
    -   Add the `bind = $mainMod, W, exec, $UserScripts/WallpaperSelect.sh` line to your Hyprland keybinding configuration file (`~/.config/hypr/UserConfigs/UserKeybinds.conf` in this setup).

4.  **Create Wallpaper Directory**:
    -   Ensure you have a `~/Pictures/wallpapers` directory, or update the `wallDIR` variable in `WallpaperSelect.sh` to point to your preferred location.

5.  **Verify Quickshell Paths**:
    -   The scripts and QML code rely on paths like `~/.local/state/caelestia/`. These are generally handled by the Caelestia Shell's own setup, but ensure you have the necessary permissions for these directories to be created and written to.

---

## Section 2: Detailed Script Logic (`qs-dynamic-colors`)

This section provides a deeper dive into the internal workings of the `qs-dynamic-colors` script.

### Color Manipulation Functions

The script defines several Bash functions to handle color conversions and modifications.

**1. `get_luminance()`**
This function is critical for making intelligent color choices. It takes a hex color code (e.g., `#89b4fa`) and calculates its perceived brightness.

-   **Logic**:
    1.  It separates the hex code into its Red (R), Green (G), and Blue (B) components.
    2.  It applies a standard formula (`(R*299 + G*587 + B*114) / 1000`) that weights each component according to how the human eye perceives its brightness. Green appears brightest, followed by red, then blue.
    3.  It returns a value between 0 (black) and 255 (white).
-   **Purpose**: To determine if a color is light or dark, which is essential for selecting background, surface, and accent colors that contrast well.

**2. `darken_color()` and `lighten_color()`**
These functions are used to create variations of the extracted colors.

-   **Logic**:
    -   `darken_color`: Multiplies the R, G, and B values by 0.8 (an 80% tint), effectively making the color 20% darker.
    -   `lighten_color`: Adds a fixed value of 80 to each R, G, and B component (capping at 255) to make the color significantly brighter.
-   **Purpose**: To derive related colors from a single source color. For example, the `SECONDARY` color is a darkened version of the `BEST_ACCENT` color, and the `SURFACE` is a lightened version of the `BEST_PRIMARY` color, ensuring harmonic relationships between them.

### Wallpaper Brightness Detection

Before selecting colors, the script determines if the wallpaper is predominantly light or dark. This allows it to tailor the theme more appropriately.

-   **Logic**:
    1.  It calculates the luminance of all 12 extracted colors using the `get_luminance` function.
    2.  It computes the average brightness across all colors.
    3.  If the `AVERAGE_BRIGHTNESS` is below a threshold (80), it classifies the wallpaper as "dark".
-   **Purpose**: This classification changes the acceptable luminance ranges for primary and accent colors. For a dark wallpaper, it will look for darker primary colors and more vibrant accents to create a more balanced and less jarring theme.

### Intelligent Color Assignment

This is the final step where the script assigns the extracted colors to specific roles in the theme.

-   **Logic**:
    1.  It iterates through the array of 12 colors from ImageMagick.
    2.  It uses the luminance value of each color to find the first one that fits within the predefined ranges for `BEST_ACCENT` and `BEST_PRIMARY`.
    3.  It then assigns the final theme colors (`PRIMARY`, `SECONDARY`, `TERTIARY`, etc.) using the best-fit colors it found.
    4.  **Fallbacks**: If no suitable color is found in the wallpaper for a specific role (e.g., no color is bright enough to be an accent), it uses a hardcoded fallback color (e.g., `#89b4fa` for `PRIMARY`). This ensures the UI is always usable, even with monochromatic or unusual wallpapers.
    5.  **Static Background**: The `BACKGROUND` color is always set to a static dark color (`#1e1e2e`) to ensure readability and a consistent base, regardless of the wallpaper.