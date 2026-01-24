# TrackIR/FreeTrack Setup for Nuclear Option (Linux + Proton)

This guide shows how to use your Docker OpenTrack with Steam Proton games that support TrackIR/FreeTrack (like Nuclear Option).

## Overview

Since Nuclear Option runs through Steam Proton (Windows compatibility layer), we use a **UDP bridge** setup:

```
[Docker OpenTrack] → UDP → [Windows OpenTrack in Proton] → FreeTrack → [Nuclear Option]
     (Linux)                    (Windows in Wine)              (TrackIR Protocol)
```

## Part 1: Configure Docker OpenTrack (Main Tracker)

### 1. Start Your Docker OpenTrack

```bash
cd ~/projects/four43/dotfiles/opentrack
docker compose up
```

### 2. Configure OpenTrack

In the OpenTrack GUI:

**Input (Tracker):**
- Select: **"NeuralNet head pose estimator"** (or your preferred tracker)
- Click camera icon → select your webcam
- Choose model: `head-pose-0.4-small-f32.onnx`

**Output (Protocol):**
- Select: **"UDP over network"**
- Click settings icon next to Output
- Configure:
  - **IP Address:** `127.0.0.1` (localhost)
  - **Port:** `4242` (default)
  - Leave other settings as default
  - Click OK

**Mapping/Filter:**
- Set up your curves and filters as desired
- Click "Start" to begin tracking

### 3. Verify UDP Output

Test that UDP packets are being sent:

```bash
# In another terminal, listen for UDP packets
nc -ul 4242
```

You should see data flowing when you move your head. Press Ctrl+C to stop.

## Part 2: Install Windows OpenTrack in Proton Prefix

### 1. Find Nuclear Option Installation

```bash
# Find the game directory
find ~/.steam -name "Nuclear Option" -type d 2>/dev/null
# Or typically at:
ls ~/.steam/steam/steamapps/common/
```

### 2. Find the Proton Prefix

```bash
# Find the compatdata directory for Nuclear Option
# App ID for Nuclear Option is 2168680
ls -la ~/.steam/steam/steamapps/compatdata/2168680/pfx/

# This is your WINEPREFIX for the game
export WINEPREFIX="$HOME/.steam/steam/steamapps/compatdata/2168680/pfx"
```

### 3. Download Windows OpenTrack Portable

```bash
cd /tmp
wget https://github.com/opentrack/opentrack/releases/download/opentrack-2023.3.0/opentrack-2023.3.0-win32-setup.exe
# Or download the portable version:
wget https://github.com/opentrack/opentrack/releases/download/opentrack-2023.3.0/opentrack-2023.3.0-win32-portable.7z
```

### 4. Extract to Game Directory

```bash
# Extract portable version
mkdir -p /tmp/opentrack-windows
cd /tmp/opentrack-windows
7za x /tmp/opentrack-2023.3.0-win32-portable.7z

# Copy to a shared location accessible by Proton
# Option A: Copy to game directory
cp -r install "$HOME/.steam/steam/steamapps/common/Nuclear Option/opentrack"

# Option B: Copy to Proton prefix drive_c
cp -r install "$HOME/.steam/steam/steamapps/compatdata/2168680/pfx/drive_c/opentrack"
```

### 5. Create Launcher Script

Create a file: `~/.steam/steam/steamapps/common/Nuclear Option/launch-with-tracking.sh`

```bash
#!/bin/bash

# Set the Proton/Wine prefix
export WINEPREFIX="$HOME/.steam/steam/steamapps/compatdata/2168680/pfx"

# Find Proton (use the version Steam uses for this game)
PROTON_PATH="$HOME/.steam/steam/steamapps/common/Proton 8.0"  # Adjust version as needed
export PROTON_EXE="$PROTON_PATH/proton"

# Start Windows OpenTrack in background
"$PROTON_EXE" run "$WINEPREFIX/drive_c/opentrack/opentrack.exe" &

# Wait a moment for OpenTrack to initialize
sleep 3

# The game will be launched by Steam's normal launch command
# This script just ensures OpenTrack starts first
```

Make it executable:
```bash
chmod +x ~/.steam/steam/steamapps/common/Nuclear\ Option/launch-with-tracking.sh
```

### 6. Configure Windows OpenTrack (in Wine/Proton)

You need to run the Windows OpenTrack once to configure it:

```bash
# Set environment
export WINEPREFIX="$HOME/.steam/steam/steamapps/compatdata/2168680/pfx"
PROTON_PATH="$HOME/.steam/steam/steamapps/common/Proton 8.0"

# Run Windows OpenTrack
"$PROTON_PATH/proton" run "$WINEPREFIX/drive_c/opentrack/opentrack.exe"
```

In the Windows OpenTrack GUI:

**Input:**
- Select: **"UDP over network"**
- Click settings:
  - **Port:** `4242`
  - **Add loopback:** ✓ (checked)

**Output:**
- Select: **"freetrack 2.0 Enhanced"**
- Leave default settings

**Save and close** (don't click Start yet)

## Part 3: Launch Nuclear Option with Head Tracking

### Option A: Manual Launch (Recommended for testing)

1. **Start Docker OpenTrack** (if not already running):
   ```bash
   docker compose up
   ```
   Configure and click "Start"

2. **Start Windows OpenTrack in Proton**:
   ```bash
   export WINEPREFIX="$HOME/.steam/steam/steamapps/compatdata/2168680/pfx"
   "$HOME/.steam/steam/steamapps/common/Proton 8.0/proton" run \
     "$WINEPREFIX/drive_c/opentrack/opentrack.exe" &
   ```
   Click "Start" in this OpenTrack too

3. **Launch Nuclear Option from Steam** normally

### Option B: Steam Launch Options

In Steam:
1. Right-click **Nuclear Option** → **Properties**
2. Under **Launch Options**, add:
   ```bash
   bash -c 'export WINEPREFIX="$HOME/.steam/steam/steamapps/compatdata/2168680/pfx"; \
   "$HOME/.steam/steam/steamapps/common/Proton 8.0/proton" run \
   "$WINEPREFIX/drive_c/opentrack/opentrack.exe" & sleep 3; %command%'
   ```

3. Make sure Docker OpenTrack is running before launching the game

### Option C: Using Protontricks (Easiest)

Install protontricks:
```bash
# Ubuntu/Debian
sudo apt install protontricks

# Or via pip
pip install protontricks
```

Then:
```bash
# Find Nuclear Option's App ID
protontricks -s "nuclear option"

# Run Windows OpenTrack in the game's prefix
protontricks-launch --appid 2168680 /path/to/opentrack.exe
```

## Part 4: In-Game Configuration

1. Launch Nuclear Option
2. Go to game **Settings/Options**
3. Look for **Head Tracking**, **TrackIR**, or **Camera** settings
4. **Enable TrackIR** support
5. You may need to calibrate/adjust sensitivity

## Troubleshooting

### Docker OpenTrack Not Sending Data

```bash
# Check if OpenTrack is running
docker ps | grep opentrack

# Check UDP output
nc -ul 4242
# Move your head - you should see data
```

### Windows OpenTrack Not Receiving Data

In Windows OpenTrack:
- Verify Input is "UDP over network"
- Check port is 4242
- Ensure "Add loopback" is enabled

### Game Not Detecting TrackIR

1. Make sure Windows OpenTrack is running BEFORE launching the game
2. Verify output is set to "freetrack 2.0 Enhanced"
3. Check in-game settings for TrackIR/FreeTrack toggle
4. Try restarting the game after OpenTrack is running

### Finding the Correct Proton Version

```bash
# Check which Proton version Steam uses for Nuclear Option
cat ~/.steam/steam/steamapps/compatdata/2168680/version
```

## Alternative: Simpler Setup with opentrack-launcher

There's a third-party tool that automates this process:

```bash
git clone https://github.com/markx86/opentrack-launcher.git
cd opentrack-launcher
# Follow the README instructions
```

## References

- [Steam Guide: Linux Head Tracking with Proton and OpenTrack](https://steamcommunity.com/sharedfiles/filedetails/?id=2972803012)
- [OpenTrack Discussion: Proton Support](https://github.com/opentrack/opentrack/discussions/1585)
- [Nuclear Option TrackIR Support Discussion](https://steamcommunity.com/app/2168680/discussions/0/4353366080391057713/)
