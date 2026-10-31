---
sidebar_position: 1
title: Audio engine
sidebar_label: Audio engine
slug: /audio
---

# Audio engine

Serpantinum ships its own small audio processor, [serpantinum-audio](https://github.com/ilyamiro/serpantinum-audio). It replaces EasyEffects and depends only on PipeWire. The equalizer, balance, mono, channel swap, dynamic range modes and the dynamic EQ in the music popup all run on it.

It creates a virtual output called **Serpantinum**, processes everything sent to it and plays the result on your real output device. The shell talks to it over a local socket, so changing a slider is instant.

## In the shell

- `serpantinumd start` starts the engine, so it runs whenever the shell does.
- The **Serpantinum** output appears in the volume popup next to your devices, just as the EasyEffects sink did. It is the default output while the engine runs.
- Choosing a device in the volume popup moves the processed audio to that device, and the popup highlights the device you are actually listening on. When the engine stops, your previous default output comes back.
- Settings survive a reboot. The engine keeps them in `~/.local/state/serpantinum/audio.state`, and the music popup reads them back from there.

## Dynamic EQ

The **Dynamic** button on the equalizer page turns on an adaptive tonal balance. It listens to the last few seconds of audio and gently moves the balance toward the typical balance of commercial recordings, without changing loudness. It replaces the manual equalizer while it is on, so the sliders and presets are dimmed until you turn it off.

The design and the research behind each number are described in the [serpantinum-audio README](https://github.com/ilyamiro/serpantinum-audio#dynamic-eq).

## Installation

The install script downloads the latest release for `x86_64` or `aarch64`, checks it against the published checksums and installs it to `/usr/local/bin`. Prebuilt binaries need glibc 2.39 or newer. On other systems, such as Void Linux musl, the installer installs a compiler and the PipeWire development files and builds it from source. Running the installer again updates it.

The Arch packages bundle a release, and the Nix flake builds it from source.

## Moving from EasyEffects

The first time the shell starts with the audio engine installed, it hands your audio over to it. This runs once:

- stops and disables the EasyEffects user service, and removes a plain-file `ee-eq.service` if you have one
- stops a running EasyEffects process
- removes the EasyEffects autostart entry and the `live_eq` preset that Serpantinum used to generate
- removes the old `systemctl --user enable --now easyeffects` line from your Hyprland, Niri, Sway and Mango configs, keeping a `.pre-audio-engine.bak` copy of each file it edits

EasyEffects itself stays installed and your own presets are untouched. EasyEffects can also process the microphone, which Serpantinum does not, so if you rely on that you can start it again yourself.

If your EasyEffects service is declared in Home Manager or NixOS, for example with `services.easyeffects.enable = true`, the unit is a read-only link into the Nix store. Serpantinum stops it for the session, but it comes back at the next login until you remove that option from your configuration.
