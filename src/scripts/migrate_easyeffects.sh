#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"

MARKER="$QS_STATE_DIR/easyeffects-migrated"
LOCKED="$QS_STATE_DIR/easyeffects-autostart-locked"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
UNITS=(easyeffects.service ee-eq.service)
COMPOSITOR_DIRS=(hypr niri sway mango)
AUTOSTART_REGEX='^[[:space:]]*(exec systemctl --user enable --now easyeffects|exec_once=systemctl --user enable --now easyeffects|hl\.exec_cmd\("systemctl --user enable --now easyeffects"\)|spawn-at-startup "systemctl" "--user" "enable" "--now" "easyeffects")[[:space:]]*$'

command -v serpantinum-audio >/dev/null 2>&1 || exit 0
[ -f "$MARKER" ] && [ ! -f "$LOCKED" ] && exit 0

if command -v systemctl >/dev/null 2>&1 && ! systemctl --user show-environment >/dev/null 2>&1; then
    exit 0
fi

stop_services() {
    local unit
    if command -v systemctl >/dev/null 2>&1; then
        for unit in "${UNITS[@]}"; do
            systemctl --user disable --now "$unit" >/dev/null 2>&1 || systemctl --user stop "$unit" >/dev/null 2>&1 || true
        done
    fi
    if command -v dinitctl >/dev/null 2>&1; then
        dinitctl --user stop easyeffects >/dev/null 2>&1 || true
        dinitctl --user disable easyeffects >/dev/null 2>&1 || true
    fi
}

remove_unit_files() {
    local unit file removed=false
    for unit in "${UNITS[@]}"; do
        file="$CONFIG_HOME/systemd/user/$unit"
        if [ -f "$file" ] && [ ! -L "$file" ] && grep -q easyeffects "$file" 2>/dev/null; then
            rm -f "$file"
            removed=true
        fi
    done
    if [ "$removed" = true ] && command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi
}

stop_process() {
    local waited=0
    pgrep -x easyeffects >/dev/null 2>&1 || return 0
    pkill -TERM -x easyeffects >/dev/null 2>&1 || true
    while pgrep -x easyeffects >/dev/null 2>&1 && [ "$waited" -lt 20 ]; do
        sleep 0.1
        waited=$((waited + 1))
    done
    pkill -KILL -x easyeffects >/dev/null 2>&1 || true
}

remove_generated_files() {
    rm -f "$CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop"
    rm -f "$DATA_HOME/easyeffects/output/live_eq.json"
}

clean_autostart_lines() {
    local dir_name dir file
    for dir_name in "${COMPOSITOR_DIRS[@]}"; do
        dir="$CONFIG_HOME/$dir_name"
        [ -d "$dir" ] || continue
        while IFS= read -r file; do
            [ -n "$file" ] && [ -f "$file" ] && [ ! -L "$file" ] && [ -w "$file" ] || continue
            [ -e "$file.pre-audio-engine.bak" ] || cp -p "$file" "$file.pre-audio-engine.bak"
            sed -i -E "\\#$AUTOSTART_REGEX#d" "$file"
        done < <(grep -RlE "$AUTOSTART_REGEX" "$dir" --exclude='*.bak' 2>/dev/null)
    done
}

autostart_line_remains() {
    local dir_name dir
    for dir_name in "${COMPOSITOR_DIRS[@]}"; do
        dir="$CONFIG_HOME/$dir_name"
        [ -e "$dir" ] || continue
        grep -RqE "$AUTOSTART_REGEX" "$dir" --exclude='*.bak' 2>/dev/null && return 0
    done
    return 1
}

keep_easyeffects_stopped() {
    if ! autostart_line_remains; then
        rm -f "$LOCKED"
        return
    fi
    stop_services
    stop_process
    (
        sleep 8
        stop_services
        stop_process
    ) >/dev/null 2>&1 &
}

if [ -f "$MARKER" ]; then
    keep_easyeffects_stopped
    exit 0
fi

stop_services
remove_unit_files
stop_process
remove_generated_files
clean_autostart_lines

mkdir -p "$QS_STATE_DIR"
if autostart_line_remains; then
    : > "$LOCKED"
else
    rm -f "$LOCKED"
fi
: > "$MARKER"
