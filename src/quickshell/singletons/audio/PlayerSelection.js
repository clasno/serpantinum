.pragma library

function busName(player) {
    // Quickshell exposes dbusName; accept busName from older adapters as well.
    return String(player.dbusName || player.busName || "");
}

// Match application identifiers, never track metadata. Instance suffixes are
// deliberately ignored for classification, but retained for deterministic order.
function application(player) {
    const bus = busName(player).toLowerCase().replace(/^org\.mpris\.mediaplayer2\./, "");
    const identity = String(player.identity || "").trim().toLowerCase();
    if (/^spotify(?:[._-]|$)/.test(bus) || identity === "spotify") return "spotify";
    const browser = /^(?:brave|chromium|chromium-browser|google-chrome|chrome|firefox|firefox-esr|librewolf|floorp|zen|vivaldi|opera|microsoft-edge|msedge|epiphany)(?:[._-]|$)/;
    const browserIdentity = /^(?:brave|chromium|google chrome|chrome|mozilla firefox|firefox|librewolf|floorp|zen browser|vivaldi|opera|microsoft edge|epiphany|gnome web)(?: browser)?$/;
    return browser.test(bus) || browserIdentity.test(identity) ? "browser" : "other";
}

function select(players, mode, lastPlayingBus, stoppedState) {
    let candidates = players.filter(p => p).slice().sort((a, b) => busName(a).localeCompare(busName(b)));
    if (mode === "spotify-only") candidates = candidates.filter(p => application(p) === "spotify");
    if (mode === "browser-only") candidates = candidates.filter(p => application(p) === "browser");
    if (mode === "prefer-spotify") {
        const spotify = candidates.find(p => p.isPlaying && application(p) === "spotify");
        if (spotify) return spotify;
    }
    // Keep Automatic's existing fallback order, including paused players.
    return candidates.find(p => p.isPlaying)
        || candidates.find(p => lastPlayingBus !== "" && busName(p) === lastPlayingBus)
        || candidates.find(p => p.playbackState !== stoppedState && p.trackTitle !== "")
        || candidates.find(p => p.canControl)
        || candidates[0] || null;
}
