#!/bin/bash

# Upgraded Dynamic Color Extraction for Quickshell (v6 - Optimized Visibility)
#
# Usage:
#   qs-dynamic-colors /path/to/wallpaper.jpg
#   qs-dynamic-colors --mode light /path/to/wallpaper.jpg
#   qs-dynamic-colors --mode dark /path/to/wallpaper.jpg

# --- Configuration & Argument Parsing ---

MODE_STATE_FILE="$HOME/.local/state/caelestia/current_mode.txt"
DEFAULT_MODE="dark"

# Read saved mode from state file, or use default
if [ -f "$MODE_STATE_FILE" ]; then
  SAVED_MODE=$(cat "$MODE_STATE_FILE")
else
  SAVED_MODE=$DEFAULT_MODE
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  --mode)
    MODE_ARG="$2"
    shift
    shift
    ;;
  *) # Assume the last argument is the wallpaper
    WALLPAPER="$1"
    shift
    ;;
  esac
done

# Command-line argument takes precedence over saved state
THEME_MODE="${MODE_ARG:-$SAVED_MODE}"

# --- Pre-flight Checks ---
if [ -z "$WALLPAPER" ]; then
  echo "Error: Wallpaper path not provided."
  echo "Usage: $0 [--mode light|dark] /path/to/wallpaper.jpg"
  exit 1
fi
if [ ! -f "$WALLPAPER" ]; then
  echo "Error: Wallpaper file not found: $WALLPAPER"
  exit 1
fi
if ! command -v magick &>/dev/null; then
  echo "Error: 'magick' (ImageMagick) command not found."
  exit 1
fi

# --- Color Extraction ---
echo "Extracting colors for ${THEME_MODE} mode from $WALLPAPER..."
# Extract colors with enhanced saturation for better vibrancy
COLORS=$(magick "$WALLPAPER" -resize 200x200 -modulate 100,140,100 -colors 30 -unique-colors txt:- | grep -o '#[0-9A-F]\{6\}' | head -30)

if [ -z "$COLORS" ]; then
  echo "Error: ImageMagick could not extract any colors from the image."
  exit 1
fi

IFS=$'\n' read -d '' -r -a COLOR_ARRAY <<<"$COLORS"

# --- Helper Functions ---
get_luminance() {
  local r=$((0x${1:1:2}))
  local g=$((0x${1:3:2}))
  local b=$((0x${1:5:2}))
  echo $(((r * 299 + g * 587 + b * 114) / 1000))
}

get_saturation() {
  local r=$((0x${1:1:2}))
  local g=$((0x${1:3:2}))
  local b=$((0x${1:5:2}))
  local max=$((r > g ? (r > b ? r : b) : (g > b ? g : b)))
  local min=$((r < g ? (r < b ? r : b) : (g < b ? g : b)))
  if [ $max -eq 0 ]; then
    echo 0
  else
    echo $(((max - min) * 100 / max))
  fi
}

darken_color_safe() {
  local color="$1"
  local factor="${2:-50}"         # Darkening percentage
  local min_brightness="${3:-40}" # Minimum RGB value to maintain visibility

  local r=$((0x${color:1:2}))
  local g=$((0x${color:3:2}))
  local b=$((0x${color:5:2}))

  # Darken each component
  r=$((r * (100 - factor) / 100))
  g=$((g * (100 - factor) / 100))
  b=$((b * (100 - factor) / 100))

  # Ensure minimum brightness for visibility (never pure black)
  # Keep some of the original color tone
  local max_original=$((r > g ? (r > b ? r : b) : (g > b ? g : b)))
  if [ $max_original -lt $min_brightness ]; then
    # If already too dark, lighten instead
    local boost=$((min_brightness - max_original))
    r=$((r + boost))
    g=$((g + boost))
    b=$((b + boost))
  fi

  # Ensure minimum values
  [ $r -lt $min_brightness ] && r=$min_brightness
  [ $g -lt $min_brightness ] && g=$min_brightness
  [ $b -lt $min_brightness ] && b=$min_brightness

  # Cap at 255
  [ $r -gt 255 ] && r=255
  [ $g -gt 255 ] && g=255
  [ $b -gt 255 ] && b=255

  printf "#%02X%02X%02X" $r $g $b
}

lighten_color() {
  local color="$1"
  local factor="${2:-30}"
  local r=$((0x${color:1:2}))
  local g=$((0x${color:3:2}))
  local b=$((0x${color:5:2}))

  r=$((r + (255 - r) * factor / 100))
  g=$((g + (255 - g) * factor / 100))
  b=$((b + (255 - b) * factor / 100))

  [ $r -gt 255 ] && r=255
  [ $g -gt 255 ] && g=255
  [ $b -gt 255 ] && b=255

  printf "#%02X%02X%02X" $r $g $b
}

ensure_minimum_contrast() {
  local bg_color="$1"
  local fg_color="$2"
  local min_diff="${3:-80}" # Minimum luminance difference

  local bg_lum=$(get_luminance "$bg_color")
  local fg_lum=$(get_luminance "$fg_color")
  local diff=$((fg_lum > bg_lum ? fg_lum - bg_lum : bg_lum - fg_lum))

  if [ $diff -lt $min_diff ]; then
    # Increase contrast
    if [ $fg_lum -gt $bg_lum ]; then
      # Lighten foreground
      fg_color=$(lighten_color "$fg_color" 35)
    else
      # Darken foreground
      fg_color=$(darken_color_safe "$fg_color" 35 30)
    fi
  fi

  echo "$fg_color"
}

# --- Intelligent Color Selection ---
echo "Analyzing wallpaper colors for optimal visibility..."

# Sort colors by luminance and saturation
declare -a SORTED_COLORS
for color in "${COLOR_ARRAY[@]}"; do
  lum=$(get_luminance "$color")
  sat=$(get_saturation "$color")
  # Score colors by both luminance and saturation for better selection
  score=$((lum + sat / 2))
  SORTED_COLORS+=("$score:$lum:$sat:$color")
done

# Sort by score
IFS=$'\n' SORTED_COLORS=($(sort -rn <<<"${SORTED_COLORS[*]}"))

# Initialize color categories
DARKEST=""
DARK=""
MEDIUM=""
BRIGHT=""
BRIGHTEST=""
MOST_SATURATED=""
BEST_SATURATION=0

# Categorize colors
for entry in "${SORTED_COLORS[@]}"; do
  score="${entry%%:*}"
  rest="${entry#*:}"
  lum="${rest%%:*}"
  rest="${rest#*:}"
  sat="${rest%%:*}"
  color="${rest#*:}"

  # Categorize by luminance
  if [[ -z "$DARKEST" && $lum -ge 30 && $lum -le 70 ]]; then
    DARKEST="$color"
  elif [[ -z "$DARK" && $lum -gt 70 && $lum -le 100 ]]; then
    DARK="$color"
  elif [[ -z "$MEDIUM" && $lum -gt 100 && $lum -le 150 ]]; then
    MEDIUM="$color"
  elif [[ -z "$BRIGHT" && $lum -gt 150 && $lum -le 200 ]]; then
    BRIGHT="$color"
  elif [[ -z "$BRIGHTEST" && $lum -gt 200 ]]; then
    BRIGHTEST="$color"
  fi

  # Track most saturated color with decent brightness
  if [[ $sat -gt $BEST_SATURATION && $lum -gt 80 && $lum -lt 220 ]]; then
    MOST_SATURATED="$color"
    BEST_SATURATION=$sat
  fi
done

# Select best colors with fallbacks
BASE_COLOR="${MEDIUM:-${DARK:-${BRIGHT:-#5e6b7a}}}"
ACCENT_COLOR="${BRIGHT:-${BRIGHTEST:-${MEDIUM:-#89a4c7}}}"
VIBRANT_COLOR="${MOST_SATURATED:-${BRIGHT:-#a89bc7}}"

echo "Selected base: $BASE_COLOR (lum: $(get_luminance "$BASE_COLOR"))"
echo "Selected accent: $ACCENT_COLOR (lum: $(get_luminance "$ACCENT_COLOR"))"
echo "Selected vibrant: $VIBRANT_COLOR (sat: $(get_saturation "$VIBRANT_COLOR")%)"

if [ "$THEME_MODE" == "light" ]; then
  # --- Light Mode ---
  BACKGROUND=$(lighten_color "$BASE_COLOR" 85)
  SURFACE=$(lighten_color "$BASE_COLOR" 70)
  PRIMARY=$(darken_color_safe "$ACCENT_COLOR" 20 40)
  SECONDARY=$(darken_color_safe "$VIBRANT_COLOR" 15 40)
  TERTIARY="$VIBRANT_COLOR"
  ON_BACKGROUND="#1a1a1a"
  ON_PRIMARY="#fcfcfc"
else
  # --- Dark Mode with Optimized Visibility ---
  # Background: Dark but never black, maintains color tone
  BACKGROUND=$(darken_color_safe "$BASE_COLOR" 55 35) # Min RGB 35 prevents black

  # Surface: Noticeably lighter than background for UI visibility
  SURFACE=$(darken_color_safe "$BASE_COLOR" 35 50) # Min RGB 50 for UI elements

  # Surface Container: Even lighter for better layering
  SURFACE_CONTAINER=$(darken_color_safe "$BASE_COLOR" 20 60)

  # Primary: Ensure bright enough for visibility
  primary_lum=$(get_luminance "$ACCENT_COLOR")
  if [ $primary_lum -lt 150 ]; then
    PRIMARY=$(lighten_color "$ACCENT_COLOR" 40)
  else
    PRIMARY="$ACCENT_COLOR"
  fi

  # Secondary & Tertiary: Vibrant and visible
  vibrant_lum=$(get_luminance "$VIBRANT_COLOR")
  if [ $vibrant_lum -lt 140 ]; then
    ACCENT=$(lighten_color "$VIBRANT_COLOR" 45)
  else
    ACCENT="$VIBRANT_COLOR"
  fi

  # Ensure contrast between primary and accent
  PRIMARY=$(ensure_minimum_contrast "$BACKGROUND" "$PRIMARY" 100)
  ACCENT=$(ensure_minimum_contrast "$BACKGROUND" "$ACCENT" 100)

  # Generate variations
  SECONDARY=$(magick "xc:$PRIMARY" -modulate 105,95,100 -format "%[hex]" info:-)
  TERTIARY=$(magick "xc:$ACCENT" -modulate 110,115,100 -format "%[hex]" info:-)

  ON_BACKGROUND="#d4d8e8"
  ON_PRIMARY="#2a2a3a"
fi

# Ensure proper formatting and minimum brightness
format_and_validate() {
  local color="$1"
  local min_lum="${2:-30}"

  if [[ ! "$color" =~ ^# ]]; then
    color="#$color"
  fi

  local lum=$(get_luminance "$color")
  if [ $lum -lt $min_lum ]; then
    color=$(lighten_color "$color" 20)
  fi

  echo "$color"
}

BACKGROUND=$(format_and_validate "$BACKGROUND" 25)
SURFACE=$(format_and_validate "$SURFACE" 35)
SURFACE_CONTAINER=$(format_and_validate "${SURFACE_CONTAINER:-$SURFACE}" 40)
PRIMARY=$(format_and_validate "$PRIMARY" 100)
SECONDARY=$(format_and_validate "${SECONDARY:-$PRIMARY}" 90)
TERTIARY=$(format_and_validate "${TERTIARY:-$ACCENT}" 95)

# --- Save current mode to state file ---
mkdir -p "$(dirname "$MODE_STATE_FILE")"
echo "$THEME_MODE" >"$MODE_STATE_FILE"

# --- JSON Output ---
SCHEME_FILE="$HOME/.local/state/caelestia/scheme.json"
mkdir -p "$(dirname "$SCHEME_FILE")"

cat >"$SCHEME_FILE" <<EOF
{
  "name": "dynamic",
  "flavour": "${THEME_MODE}",
  "mode": "${THEME_MODE}",
  "colours": {
    "background": "${BACKGROUND#\#}",
    "onBackground": "${ON_BACKGROUND#\#}",
    "surface": "${SURFACE#\#}",
    "onSurface": "${ON_BACKGROUND#\#}",
    "surfaceContainer": "${SURFACE_CONTAINER#\#}",
    "surfaceContainerHigh": "${SURFACE#\#}",
    "onSurfaceVariant": "$([ "$THEME_MODE" == "light" ] && echo "4a4a4a" || echo "b8c0d8")",
    "primary": "${PRIMARY#\#}",
    "onPrimary": "${ON_PRIMARY#\#}",
    "secondary": "${SECONDARY#\#}",
    "onSecondary": "${ON_PRIMARY#\#}",
    "tertiary": "${TERTIARY#\#}",
    "onTertiary": "${ON_PRIMARY#\#}",
    "outline": "${PRIMARY#\#}",
    "outlineVariant": "${ACCENT:-$TERTIARY#\#}",
    "scrim": "000000",
    "shadow": "000000"
  }
}
EOF

echo ""
echo "=== Optimized Color Scheme ==="
echo "Mode: $THEME_MODE"
echo "Background: $BACKGROUND (lum: $(get_luminance "$BACKGROUND")) - Never black"
echo "Surface: $SURFACE (lum: $(get_luminance "$SURFACE")) - UI visible"
echo "Primary: $PRIMARY (lum: $(get_luminance "$PRIMARY")) - High visibility"
echo "Secondary: $SECONDARY (lum: $(get_luminance "$SECONDARY"))"
echo "Tertiary: $TERTIARY (lum: $(get_luminance "$TERTIARY"))"
echo ""
echo "Scheme saved to: $SCHEME_FILE"

# Wait for file write
sleep 2

# Clear caches
rm -f ~/.cache/quickshell/* 2>/dev/null

# --- Restart Quickshell ---
if pgrep -f "qs.*caelestia" >/dev/null; then
  echo "Restarting Quickshell..."
  pkill -f "qs.*caelestia"
  sleep 3
fi
qs -c caelestia &
echo "Quickshell restarted with optimized visibility!"
