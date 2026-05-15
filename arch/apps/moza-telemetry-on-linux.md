# Moza KS Pro + R12 V2 telemetry on Linux

Notes on getting in-game telemetry onto the wheel/rim while playing on Linux
(specifically Assetto Corsa Competizione via Steam/Proton). Saved 2026-04-24.

## TL;DR

- **LEDs (rev lights, flags)**: doable on Linux via SimHub-in-Proton + the
  community moza-simhub-plugin.
- **2.99" LCD on the KS Pro**: not realistically doable on Linux today. The
  screen is driven by Moza's proprietary Sim Dashboard / Pit House pipeline,
  which is Windows-only and doesn't survive Wine (low-level HID comms).
- The moza-simhub-plugin README explicitly says LCD/screen updates are "a
  work in progress and may or may not work" — LEDs are the reliable part.

## Why Pit House isn't an option

Moza Pit House is Windows-only and talks to the base over USB HID directly.
Wine/Proton don't pass that through cleanly, and Pit House is the only thing
that fully drives the KS Pro's screen.

## What works: SimHub + moza-simhub-plugin under Proton

Drives the 10 RGB rev lights and 6 flag LEDs from ACC telemetry. ACC writes
its shared-memory telemetry inside the Proton prefix, so SimHub running in
the same prefix can read it.

Rough setup:

1. In the ACC Proton prefix, install .NET 4.8:
   `WINEPREFIX=<acc-prefix> winetricks dotnet48`
2. Install SimHub into that same prefix. Skip the ".NET / C++ redist / USB
   display drivers" options.
3. Drop the moza-simhub-plugin DLL into SimHub's plugin folder.
4. Launch via Steam Tinker Launch — fork `SimHubWPF.exe` as a custom command
   with ~5s delay so the game boots first.
5. In SimHub, enable the ACC profile and bind RPM/flag effects.

Caveats:
- Finicky — expect to restart a couple times to get SimHub to attach.
- Nothing else (Boxflat, Pit House) can talk to the base at the same time:
  same serial port.

## Boxflat

Linux-native Moza config tool. Useful for wheelbase settings + Proton/SDL
fixes. Telemetry-to-screen is on the roadmap, not shipped. Worth installing
for base config regardless: <https://github.com/Lawstorant/boxflat> (also on
Flathub).

## Other options if the LCD really matters

1. **Dual-boot Windows** for sim racing. Full Pit House + native LCD
   dashboards. This is what most KS Pro owners do if they want the screen.
2. **External dashboard** (e.g. MVH Telemetry Display, or a SimHub-compatible
   USB screen). SimHub-in-Proton can drive these fine. Sidesteps the Moza
   LCD entirely.
3. **Windows VM with USB passthrough** (VFIO) running Pit House. Technically
   possible, heavy setup, probably not worth it.
4. **Wait** — moza-simhub-plugin's LCD work is in progress, Boxflat has
   telemetry on its roadmap.

## Hardware

- Wheel: Moza KS Pro (2.99" LCD, 10 RGB rev lights, 6 flag LEDs)
- Base: Moza R12 V2

## References

- moza-simhub-plugin: <https://github.com/giantorth/moza-simhub-plugin>
- SimHub on Linux guide: <https://www.simhubdash.com/community-2/simhub-support/guide-simhub-on-linux/>
- Boxflat: <https://github.com/Lawstorant/boxflat>
- KS Pro product page: <https://mozaracing.com/products/ks-pro-wheel>
- KS Pro review (notes the SimHub/Pit House split for the screen):
  <https://ocracing.com/reviews/moza-ks-pro-review/>
- MVH Telemetry Display: <https://mvhstudios.co.uk/products/telemetry-dashboard-for-logitech-fanatec-moza>
