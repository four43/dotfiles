# OpenTrack Library Load Failure - Troubleshooting Guide

## Recent Fixes Applied

Based on research from [GitHub Issue #1113](https://github.com/opentrack/opentrack/issues/1113) and [Issue #737](https://github.com/opentrack/opentrack/issues/737), several issues have been addressed:

### 1. Missing Input Device Access
**Problem:** The libevdev protocol (virtual joystick output) requires access to `/dev/input` and `/dev/uinput` devices, which were not mounted in the container.

**Fix Applied:**
- Added `/dev/input` device mapping
- Added `/dev/uinput` device mapping
- Created `input` group and added opentrack user to it

### 2. Library Loading Permissions
**Problem:** Plugin libraries need to be readable and executable by the opentrack user.

**Fix Applied:**
- Added `chmod -R a+rX` to ensure all installed files are world-readable
- Added `LD_LIBRARY_PATH` environment variable

### 3. Debug Logging Enabled
**Fix Applied:**
- Added `QT_DEBUG_PLUGINS=1` environment variable
- Added `QT_LOGGING_RULES="*.debug=true"` for verbose logging

## Understanding the Error

The "Library load failure" message comes from `logic/runtime-libraries.cpp` and is a generic error. The actual failure could be:

1. **Protocol (Output) failure** - "protocol dylib load failure"
2. **Tracker (Input) failure** - "tracker dylib load failure"
3. **Filter failure** - "filter load failure"

The specific failure should appear in the console output where you ran `docker compose up`.

## Testing the Fixes

### Step 1: Stop Current Container
```bash
docker compose down
```

### Step 2: Start with Verbose Logging
```bash
docker compose up
```

Watch the terminal for debug messages that start with:
- "protocol dylib load failure"
- "tracker dylib load failure"
- "filter load failure"

### Step 3: Test Different Configurations

Try these known-working combinations:

#### Configuration 1: PointTracker + UDP Output
- **Input:** PointTracker 1.1
- **Output:** UDP over network
- **Filter:** Accela (or none)

#### Configuration 2: Easy Tracker + UDP Output
- **Input:** Easy Tracker 1.0
- **Output:** UDP over network
- **Filter:** None

#### Configuration 3: Test Input + libevdev Output
- **Input:** Testing -- no input
- **Output:** libevdev joystick receiver
- **Filter:** None

### Step 4: Check Device Access

If still failing, verify device access:

```bash
# Check if container can see input devices
docker compose run --rm opentrack ls -la /dev/input/

# Check if container can see video device
docker compose run --rm opentrack ls -la /dev/video0

# Check if container can see uinput
docker compose run --rm opentrack ls -la /dev/uinput
```

## Common Issues and Solutions

### Issue: "Cannot open camera"
**Solution:** Select the camera in Input settings before clicking Start:
1. Select your tracker (e.g., PointTracker)
2. Click the camera icon next to Input
3. Choose your webcam from the dropdown
4. Click OK
5. Now click Start

### Issue: "Permission denied" on /dev/uinput
**Solution:** On the host, ensure uinput module is loaded:
```bash
sudo modprobe uinput
echo uinput | sudo tee -a /etc/modules-load.d/uinput.conf
```

### Issue: Still getting "library load failure"
**Solution:** Check the console output for the specific failure:

1. Look for lines like:
   - "protocol dylib load failure"
   - "tracker dylib load failure"
   - "Error occurred while loading protocol/tracker/filter"

2. The error will indicate which component failed to load

3. Report the specific error for more targeted troubleshooting

## Verification Commands

### Test All Plugins
```bash
docker run --rm -v $(pwd)/test-plugins.sh:/tmp/test.sh \
  --entrypoint /bin/bash opentrack-opentrack:latest /tmp/test.sh
```

### Check Library Dependencies
```bash
docker run --rm --entrypoint /bin/bash opentrack-opentrack:latest \
  -c "ldd /opt/opentrack/build/install/libexec/opentrack/*.so | grep 'not found'"
```

If this command produces no output, all libraries are properly linked.

## What Was Changed

### [Dockerfile](Dockerfile)
- Added `groupadd -f input` to create input group
- Added opentrack user to both `video` and `input` groups
- Added `chmod -R a+rX /opt/opentrack/build/install` for read permissions
- Added `LD_LIBRARY_PATH` for plugin directory

### [docker-compose.yml](docker-compose.yml)
- Added `/dev/input:/dev/input` device mapping
- Added `/dev/uinput:/dev/uinput` device mapping
- Added `input` to group_add
- Added `QT_DEBUG_PLUGINS=1` environment variable
- Added `QT_LOGGING_RULES` for debug output

## References

- [OpenTrack GitHub Issue #1113 - Library load failure](https://github.com/opentrack/opentrack/issues/1113)
- [OpenTrack GitHub Issue #737 - One of libraries failed to load](https://github.com/opentrack/opentrack/issues/737)
- [OpenTrack Building on Linux Wiki](https://github.com/opentrack/opentrack/wiki/Building-on-Linux)

## Getting More Help

If the issue persists, please:

1. Copy the full terminal output from `docker compose up`
2. Note which Input/Output/Filter combination you're trying
3. Run the verification commands above
4. Check if the error is specific to webcam access or happens with "Testing -- no input" too
