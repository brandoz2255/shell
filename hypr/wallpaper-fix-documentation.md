# Hyprland Wallpaper Issue Fix

## Problem
When changing wallpapers in Hyprland, waybar and swaync were being automatically launched/restarted, which was unwanted behavior.

## Root Cause
The issue was in the wallpaper change script `/home/dulc3/.config/hypr/UserScripts/WallpaperSelect.sh` at line 195, which calls `"$SCRIPTSDIR/Refresh.sh"`.

The `Refresh.sh` script contained code that would restart waybar and swaync after wallpaper changes:
- Line 38: `waybar &` - launches waybar
- Line 42: `swaync > /dev/null 2>&1 &` - launches swaync  
- Line 44: `swaync-client --reload-config` - reloads swaync config

## Solution
Modified `/home/dulc3/.config/hypr/scripts/Refresh.sh` by commenting out the waybar and swaync restart sections:

```bash
#Restart waybar
#sleep 1
#waybar &

# relaunch swaync
#sleep 0.5
#swaync > /dev/null 2>&1 &
# reload swaync
#swaync-client --reload-config
```

## Result
Now when wallpapers are changed, the script still refreshes other components (ags, rofi, wallust palettes, etc.) but no longer automatically launches waybar and swaync.

## Alternative Solutions
- Could have changed line 195 in `WallpaperSelect.sh` to use `RefreshNoWaybar.sh` instead
- Could have created a custom refresh script specifically for wallpaper changes