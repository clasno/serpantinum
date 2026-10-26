# Media source-selection checks

Run from the repository root:

```sh
python3 tests/media/run.py
```

Requires Qt 6 `qmltestrunner`, Quickshell, and Python 3 with `dbus-python` and
PyGObject. The runner does not install anything. It creates a temporary HOME,
settings and source tree, uses a private session bus, launches only test
entrypoints offscreen, and never starts or restarts the desktop shell.

## Coverage

- `tst_selection.qml`: all four modes across playing, paused, stopped and
  closed Spotify/browser combinations, application recognition, deterministic
  ties and metadata stability. Plain JavaScript player fixtures.
- `lyrics.qml`: independent `LyricsProvider` contexts, stale responses,
  A→B→A requests, the same song from two sources, immediate metadata
  invalidation and subscriber removal. No network requests.
- `lyrics_io.qml`: real asynchronous cache and local-file processes, cancelled
  track requests and local-file precedence. Temporary files only.
- `mpris.qml` / `mpris_fixture.py`: real Quickshell MPRIS discovery against
  synthetic D-Bus services. Exercises all modes, playback states, metadata
  changes, two browsers and service removal.

The tests do not drive Spotify or a real browser UI, and do not verify visual
layout. Check those manually in a development session before publishing.
