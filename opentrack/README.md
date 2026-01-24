# OpenTrack Docker Setup

This Docker setup allows you to run [opentrack](https://github.com/opentrack/opentrack) head tracking software in a container with full webcam and display support.

## Prerequisites

1. **X11 Display Server**: Required for GUI applications
2. **Webcam**: Connected at `/dev/video0` (or adjust in docker-compose.yml)
3. **Docker and Docker Compose**: Installed on your system
4. **X11 Permissions**: Allow Docker to connect to your X server

You can verify all prerequisites by running:

```bash
./check-prerequisites.sh
```

## Setup

### 1. Allow X11 Access

Before running the container, allow local connections to X server:

```bash
xhost +local:docker
```

To make this permanent, add it to your `.bashrc` or `.zshrc`.

### 2. Verify Webcam Device

Check your webcam device:

```bash
ls -l /dev/video*
v4l2-ctl --list-devices
```

If your webcam is not at `/dev/video0`, edit [docker-compose.yml](docker-compose.yml) and update the device path.

### 3. Build and Run

Build the image (this will take 5-10 minutes and create a ~4.6GB image):

```bash
docker compose build
```

Run opentrack:

```bash
docker compose up
```

To run in detached mode:

```bash
docker compose up -d
```

View logs when running detached:

```bash
docker compose logs -f
```

Stop the container:

```bash
docker compose down
```

## How It Works

### Webcam Access

The container accesses your webcam through:
- Device mapping: `/dev/video0:/dev/video0`
- Video group membership for the container user
- udev information for proper device detection

### Display Access

The GUI is displayed through:
- X11 socket forwarding: `/tmp/.X11-unix`
- `DISPLAY` environment variable
- Network host mode for easier X11 connection
- Qt/X11 compatibility flags

### Configuration Persistence

OpenTrack configuration is stored in a Docker volume (`opentrack-config`), so your settings persist between container restarts.

## Troubleshooting

### Library Load Failure

If you see "library load failure" when clicking Start:

1. Ensure you've rebuilt the image with the latest Dockerfile:
   ```bash
   docker compose down
   docker compose build
   docker compose up
   ```

2. Check that the container was created with the updated image:
   ```bash
   docker images | grep opentrack
   ```

### Webcam Not Detected

1. Check permissions:
   ```bash
   ls -l /dev/video0
   groups  # Ensure you're in the video group
   ```

2. List available video devices:
   ```bash
   v4l2-ctl --list-devices
   ```

3. Verify the webcam is accessible inside the container:
   ```bash
   docker compose run --rm opentrack ls -l /dev/video0
   ```

4. Try running the container with `--privileged` flag (less secure but useful for debugging):
   ```bash
   docker run --privileged ...
   ```

### Display Issues

1. Verify X11 access:
   ```bash
   xhost +local:docker
   echo $DISPLAY
   ```

2. Check if display socket exists:
   ```bash
   ls -la /tmp/.X11-unix
   ```

3. For Wayland users, you may need additional configuration or use XWayland.

### Camera Detection in OpenTrack

OpenTrack supports various camera inputs including:
- Standard USB webcams via Video4Linux (v4l)
- Aruco marker tracking
- **NeuralNet tracker** (AI-based face tracking with ONNX Runtime)
  - Includes pre-trained models for head pose estimation
  - No markers required - tracks your face directly
  - Multiple model sizes available (big/small, f32/int8)
- PointTracker (marker-based tracking)
- Easy Tracker (automatic feature detection)

Make sure to select the correct input method in OpenTrack's settings.

## Building from Source

The Dockerfile builds opentrack from the latest source code following the official [Linux build instructions](https://github.com/opentrack/opentrack/wiki/Building-on-Linux).

Build options can be customized by modifying the `cmake` command in the Dockerfile.

### ONNX Runtime Integration

This Docker image includes **ONNX Runtime v1.23.2** for AI-powered face tracking with the NeuralNet tracker:

- **No markers needed** - tracks your face directly using neural networks
- **Multiple pre-trained models** included:
  - `head-pose-0.4-big-f32.onnx` - Highest accuracy, slower
  - `head-pose-0.4-small-f32.onnx` - Balanced performance
  - `head-pose-0.4-big-int8.onnx` - Quantized for speed
  - `head-pose-0.4-small-int8.onnx` - Fastest, lower accuracy
  - Legacy v0.2 models also available
- **Head localizer** - `head-localizer.onnx` for face detection

ONNX Runtime is downloaded from the [official Microsoft releases](https://github.com/microsoft/onnxruntime/releases) and compiled into the image.

## Security Notes

- The container runs as a non-root user (`opentrack`) for security
- X11 forwarding (`xhost +local:docker`) allows local Docker containers to access your display
- Using `--privileged` flag gives the container elevated permissions and should be avoided in production

## Using with Steam Proton Games (TrackIR/FreeTrack)

If you want to use OpenTrack with Steam games that support **TrackIR** (like Nuclear Option, Arma 3, DCS, etc.), see the detailed guide:

📖 **[TRACKIR-SETUP.md](TRACKIR-SETUP.md)** - Complete setup guide for FreeTrack/TrackIR protocol with Proton games

**Quick Overview:**
1. Configure Docker OpenTrack to output via **UDP** (port 4242)
2. Install Windows OpenTrack in the game's Proton prefix
3. Configure Windows OpenTrack: UDP input → FreeTrack output
4. Launch both OpenTracks, then start your game

The UDP bridge method allows your Linux Docker OpenTrack to communicate with Windows games running under Proton.

## References

Based on research from:
- [OpenTrack Build Instructions](https://github.com/opentrack/opentrack/wiki/Building-on-Linux)
- [Docker Webcam Access Guide](https://hrs4real.medium.com/enabling-webcam-video-capture-within-a-docker-container-96daab9f1f09)
- [X11Docker Webcam Sharing](https://github.com/mviereck/x11docker/wiki/Sharing-webcam-with-container)
- [OpenTrack Webcam Issues](https://github.com/opentrack/opentrack/issues/1779)
