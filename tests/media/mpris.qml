import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../src/quickshell" as Shell

Item {
    id: test
    property int step: 0
    property bool failed: false
    // Keep the service instantiated before the first asynchronous discovery.
    readonly property var controller: Shell.MprisController
    readonly property var discoveredPlayers: Mpris.players.values
    function check(app, playing) {
        let player = Shell.MprisController.activePlayer;
        let actual = player ? player.identity : "";
        if (actual !== app || Shell.MprisController.isPlaying !== playing) {
            failed = true;
            console.error("FAIL: MPRIS step " + step + ": expected " + app + "/" + playing
                + ", got " + actual + "/" + Shell.MprisController.isPlaying);
            console.error("MPRIS diagnostic: mode=" + Shell.MprisController.musicSource
                + ", last=" + Shell.MprisController.lastPlayingBus + ", players="
                + JSON.stringify(Mpris.players.values.map(p => ({bus: p.dbusName, identity: p.identity,
                    playing: p.isPlaying, state: p.playbackState, title: p.trackTitle}))));
        }
    }
    function mode(value) { Shell.Config.setSetting("media.musicSource", value); }
    function change(name, action) {
        command.command = ["dbus-send", "--session", "--print-reply", "--dest=org.serpantinum.MediaTest",
            "/test", "org.serpantinum.MediaTest.Change", "string:" + name, "string:" + action];
        command.running = true;
    }
    Process {
        id: command
        onExited: function(code) {
            if (code !== 0) { test.failed = true; console.error("FAIL: fixture command exited " + code); }
        }
    }
    Timer {
        interval: 180
        repeat: true
        running: Shell.Config.dataReady
        onTriggered: {
            if (command.running) return;
            if (test.step === 0 && test.discoveredPlayers.length !== 2) return;
            switch (test.step++) {
            case 0: test.mode("automatic"); break;
            case 1: test.check("Brave", true); test.mode("prefer-spotify"); break;
            case 2: test.check("Spotify", true); test.change("spotify", "Paused"); break;
            case 3: test.check("Brave", true); test.mode("spotify-only"); break;
            case 4: test.check("Spotify", false); test.change("spotify", "Stopped"); break;
            case 5: test.check("Spotify", false); test.mode("prefer-spotify"); break;
            case 6: test.check("Brave", true); test.change("spotify", "Playing"); break;
            case 7: test.check("Spotify", true); test.change("browser", "metadata"); break;
            case 8: test.check("Spotify", true); test.mode("browser-only"); break;
            case 9: test.check("Brave", true); test.change("second", "open"); break;
            case 10: test.check("Brave", true); test.change("browser", "close"); break;
            case 11: test.check("Firefox", true); test.change("second", "close"); break;
            case 12: test.check("", false); test.mode("spotify-only"); break;
            case 13: test.check("Spotify", true); test.change("spotify", "close"); break;
            case 14:
                test.check("", false);
                if (!test.failed) console.log("PASS: MPRIS integration (synthetic D-Bus services, 14 assertions)");
                Qt.quit();
            }
        }
    }
}
