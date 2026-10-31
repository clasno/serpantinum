#!/usr/bin/env bash

set -u

REPO_ROOT="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
SCRIPT="$REPO_ROOT/src/scripts/migrate_easyeffects.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

failures=0
check() {
    if eval "$2"; then
        echo "ok    $1"
    else
        echo "FAIL  $1"
        failures=$((failures + 1))
    fi
}

export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_RUNTIME_DIR="$SANDBOX/run"
export SERPANTINUM_DIR="$REPO_ROOT/src"
export SERPANTINUM_INSTALLER=1
CALLS="$SANDBOX/calls.log"
STUBS="$SANDBOX/stubs"
MARKER="$HOME/.local/state/serpantinum/easyeffects-migrated"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$STUBS"
chmod 700 "$XDG_RUNTIME_DIR"

for tool in systemctl dinitctl pkill; do
    printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nexit 0\n' "$tool" "$CALLS" > "$STUBS/$tool"
    chmod +x "$STUBS/$tool"
done
printf '#!/usr/bin/env bash\nexit 1\n' > "$STUBS/pgrep"
chmod +x "$STUBS/pgrep"
export PATH="$STUBS:$PATH"

mkdir -p "$XDG_CONFIG_HOME/hypr/config" "$XDG_CONFIG_HOME/niri/config" "$XDG_CONFIG_HOME/sway/configDir" "$XDG_CONFIG_HOME/mango/config" \
    "$XDG_CONFIG_HOME/systemd/user" "$XDG_CONFIG_HOME/autostart" "$XDG_DATA_HOME/easyeffects/output" "$XDG_CONFIG_HOME/hypr_backup/old"

cat > "$XDG_CONFIG_HOME/hypr/config/autostart.lua" <<'LUA'
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("systemctl --user enable --now easyeffects")
  hl.exec_cmd("serpantinumd start")
end)
LUA
printf 'spawn-at-startup "bash" "-c" "wl-paste --type text --watch cliphist store"\nspawn-at-startup "systemctl" "--user" "enable" "--now" "easyeffects"\nspawn-at-startup "serpantinumd" "start"\n' > "$XDG_CONFIG_HOME/niri/config/autostart.kdl"
printf 'exec wl-paste --type text --watch cliphist store\nexec systemctl --user enable --now easyeffects\nexec serpantinumd start\n' > "$XDG_CONFIG_HOME/sway/configDir/autostart"
printf 'exec_once=wl-paste --type text --watch cliphist store\nexec_once=systemctl --user enable --now easyeffects\nexec_once=serpantinumd start\n' > "$XDG_CONFIG_HOME/mango/config/autostart.conf"
printf 'bind = SUPER, E, exec, easyeffects\n# systemctl --user enable --now easyeffects is only mentioned in this comment\n' > "$XDG_CONFIG_HOME/hypr/keep.conf"
printf 'exec systemctl --user enable --now easyeffects\n' > "$XDG_CONFIG_HOME/hypr_backup/old/autostart"
mkdir -p "$SANDBOX/store"
printf '[Service]\nExecStart=easyeffects\n' > "$SANDBOX/store/easyeffects.service"
ln -s "$SANDBOX/store/easyeffects.service" "$XDG_CONFIG_HOME/systemd/user/easyeffects.service"
printf '[Service]\nExecStart=easyeffects -l live_eq\n' > "$XDG_CONFIG_HOME/systemd/user/ee-eq.service"
printf '[Desktop Entry]\n' > "$XDG_CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop"
echo '{}' > "$XDG_DATA_HOME/easyeffects/output/live_eq.json"
echo '{}' > "$XDG_DATA_HOME/easyeffects/output/my_own_preset.json"

bash "$SCRIPT"
check "without the audio engine nothing is touched" "[ ! -s '$CALLS' ] && [ ! -f '$MARKER' ] && grep -q easyeffects '$XDG_CONFIG_HOME/sway/configDir/autostart'"

printf '#!/usr/bin/env bash\nexit 0\n' > "$STUBS/serpantinum-audio"
chmod +x "$STUBS/serpantinum-audio"

bash "$SCRIPT"
check "exit status is zero" "[ \$? -eq 0 ]"
check "services are stopped and disabled" "grep -q 'systemctl --user disable --now easyeffects.service' '$CALLS'"
check "the custom ee-eq unit is stopped too" "grep -q 'systemctl --user disable --now ee-eq.service' '$CALLS'"
check "a plain-file ee-eq unit is deleted" "[ ! -e '$XDG_CONFIG_HOME/systemd/user/ee-eq.service' ]"
check "a symlinked (Home Manager) unit is left alone" "[ -L '$XDG_CONFIG_HOME/systemd/user/easyeffects.service' ] && [ -f '$SANDBOX/store/easyeffects.service' ]"
check "the XDG autostart entry is removed" "[ ! -e '$XDG_CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop' ]"
check "the generated preset is removed" "[ ! -e '$XDG_DATA_HOME/easyeffects/output/live_eq.json' ]"
check "the user's own presets are kept" "[ -e '$XDG_DATA_HOME/easyeffects/output/my_own_preset.json' ]"
for f in hypr/config/autostart.lua niri/config/autostart.kdl sway/configDir/autostart mango/config/autostart.conf; do
    check "$f: easyeffects line removed" "! grep -q easyeffects '$XDG_CONFIG_HOME/$f'"
    check "$f: other lines kept" "grep -q 'cliphist store' '$XDG_CONFIG_HOME/$f' && grep -q 'serpantinumd' '$XDG_CONFIG_HOME/$f'"
    check "$f: backup written" "grep -q easyeffects '$XDG_CONFIG_HOME/$f.pre-audio-engine.bak'"
done
check "unrelated files that merely mention easyeffects are untouched" "[ \$(wc -l < '$XDG_CONFIG_HOME/hypr/keep.conf') -eq 2 ]"
check "older config backups are not rewritten" "grep -q easyeffects '$XDG_CONFIG_HOME/hypr_backup/old/autostart'"
check "a completion marker is written" "[ -f '$MARKER' ]"

: > "$CALLS"
bash "$SCRIPT"
check "a second run does nothing" "[ ! -s '$CALLS' ]"

rm -f "$MARKER"
printf '#!/usr/bin/env bash\n[ "$2" = "show-environment" ] && exit 1\nexit 0\n' > "$STUBS/systemctl"
bash "$SCRIPT"
check "without a reachable user session it retries later" "[ ! -f '$MARKER' ]"

rm -rf "$HOME/.local/state/serpantinum"
printf '#!/usr/bin/env bash\necho "systemctl $*" >> "%s"\nexit 0\n' "$CALLS" > "$STUBS/systemctl"
mkdir -p "$SANDBOX/store/sway"
printf 'exec systemctl --user enable --now easyeffects\nexec serpantinumd start\n' > "$SANDBOX/store/sway/autostart"
rm -f "$XDG_CONFIG_HOME/sway/configDir/autostart" "$XDG_CONFIG_HOME/sway/configDir/autostart.pre-audio-engine.bak"
ln -s "$SANDBOX/store/sway/autostart" "$XDG_CONFIG_HOME/sway/configDir/autostart"
: > "$CALLS"
bash "$SCRIPT"
check "a read-only (symlinked) config is not edited" "grep -q easyeffects '$SANDBOX/store/sway/autostart' && [ ! -e '$XDG_CONFIG_HOME/sway/configDir/autostart.pre-audio-engine.bak' ]"
check "an uneditable autostart line enables the every-start fallback" "[ -f '$HOME/.local/state/serpantinum/easyeffects-autostart-locked' ]"

: > "$CALLS"
bash "$SCRIPT"
check "with the fallback, every start stops EasyEffects again" "grep -q 'systemctl --user disable --now easyeffects.service' '$CALLS'"

rm -f "$XDG_CONFIG_HOME/sway/configDir/autostart"
printf 'exec serpantinumd start\n' > "$XDG_CONFIG_HOME/sway/configDir/autostart"
: > "$CALLS"
bash "$SCRIPT"
check "once the line is gone the fallback switches itself off" "[ ! -f '$HOME/.local/state/serpantinum/easyeffects-autostart-locked' ] && ! grep -q disable '$CALLS'"

: > "$CALLS"
bash "$SCRIPT"
check "after that, starts do nothing" "[ ! -s '$CALLS' ]"

echo "$([ "$failures" -eq 0 ] && echo 'all passed' || echo "$failures FAILED")"
[ "$failures" -eq 0 ]
