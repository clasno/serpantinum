import QtQuick
import QtTest
import "../../src/quickshell/singletons/audio/PlayerSelection.js" as Selection

TestCase {
    name: "MediaSourceSelection"

    function player(bus, playing, identity) {
        return {dbusName: "org.mpris.MediaPlayer2." + bus, identity: identity || bus,
            isPlaying: playing, playbackState: playing ? 1 : 2, trackTitle: "Track", canControl: true};
    }

    function test_modes_data() {
        let rows = [];
        for (let mode of ["automatic", "prefer-spotify", "spotify-only", "browser-only"]) {
            for (let spotify of ["playing", "paused", "stopped", "closed"]) {
                for (let browser of ["playing", "paused", "closed"]) {
                    rows.push({tag: mode + "/" + spotify + "/" + browser, mode: mode, spotify: spotify, browser: browser});
                }
            }
        }
        return rows;
    }

    function test_modes(data) {
        let s = player("spotify", data.spotify === "playing", "Spotify");
        if (data.spotify === "stopped") s.playbackState = 0;
        let b = player("chromium.instance42", data.browser === "playing", "Brave");
        let players = [];
        if (data.spotify !== "closed") players.push(s);
        if (data.browser !== "closed") players.push(b);
        let selected = Selection.select(players, data.mode, "", 0);
        if (data.mode === "spotify-only") compare(selected, data.spotify === "closed" ? null : s);
        else if (data.mode === "browser-only") compare(selected, data.browser === "closed" ? null : b);
        else if (data.mode === "prefer-spotify" && s.isPlaying) compare(selected, s);
        else if (data.browser === "playing") compare(selected, b);
        else if (data.spotify === "playing") compare(selected, s);
        else compare(selected, data.browser !== "closed" ? b : data.spotify !== "closed" ? s : null);
    }

    function test_identityAndInstances() {
        for (let name of ["brave.instance42", "chromium.instance9", "google-chrome.instance1", "firefox.instance7", "librewolf", "microsoft-edge.instance4"]) {
            compare(Selection.application(player(name, true)), "browser");
        }
        compare(Selection.application(player("unknown.instance1", true, "Brave")), "browser");
        compare(Selection.application(player("spotify.instance4", true)), "spotify");
        let other = player("vlc", true, "VLC");
        other.trackTitle = "Spotify in Brave";
        compare(Selection.application(other), "other");
        compare(Selection.select([other], "browser-only", "", 0), null);
        compare(Selection.select([], "browser-only", "", 0), null);
    }

    function test_determinismAndMetadata() {
        let a = player("firefox.instance2", true);
        let b = player("chromium.instance3", true);
        for (let mode of ["automatic", "browser-only", "prefer-spotify"]) {
            compare(Selection.select([a, b], mode, "", 0), b);
            a.trackTitle = "Changed title";
            a.position = 300;
            a.trackArtUrl = "file:///new-cover";
            compare(Selection.select([b, a], mode, a.dbusName, 0), b);
        }
        a.isPlaying = false;
        b.isPlaying = false;
        compare(Selection.select([a, b], "automatic", a.dbusName, 0), a);
        compare(Selection.select([a, b], "invalid-future-value", a.dbusName, 0), a);
    }
}
