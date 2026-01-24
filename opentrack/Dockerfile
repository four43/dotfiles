FROM ubuntu:24.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies and runtime requirements
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    ca-certificates \
    libopencv-dev \
    libproc2-dev \
    qt6-base-private-dev \
    qt6-tools-dev \
    # Runtime libraries for webcam and display
    libqt6gui6 \
    libqt6widgets6 \
    # X11 and video device support
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxrandr2 \
    libxi6 \
    libxfixes3 \
    libxcursor1 \
    libxinerama1 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libgl1 \
    libglib2.0-0 \
    v4l-utils \
    && rm -rf /var/lib/apt/lists/*

# Download and install ONNX Runtime for NeuralNet tracker support
# Using version 1.23.2 (latest stable as of Oct 2024)
WORKDIR /opt
RUN wget -q https://github.com/microsoft/onnxruntime/releases/download/v1.23.2/onnxruntime-linux-x64-1.23.2.tgz \
    && tar -xzf onnxruntime-linux-x64-1.23.2.tgz \
    && rm onnxruntime-linux-x64-1.23.2.tgz

# Set ONNX Runtime environment variables
ENV ONNXRuntime_DIR=/opt/onnxruntime-linux-x64-1.23.2
ENV ONNXRuntime_ROOT=/opt/onnxruntime-linux-x64-1.23.2

# Clone opentrack repository
WORKDIR /opt
RUN git clone https://github.com/opentrack/opentrack.git

# Build opentrack with ONNX Runtime support for NeuralNet tracker
WORKDIR /opt/opentrack
RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DONNXRuntime_DIR=${ONNXRuntime_DIR} \
    && cd build \
    && make -j$(nproc) \
    && make install

# Create a non-root user for running opentrack
# Add to video group for webcam, create and add to input group for /dev/input devices
RUN groupadd -f input && \
    useradd -m -s /bin/bash opentrack && \
    usermod -a -G video,input opentrack

# Create config directory with proper permissions
RUN mkdir -p /home/opentrack/.config/opentrack && \
    chown -R opentrack:opentrack /home/opentrack/.config

# Ensure opentrack user can read all installed files and libraries
RUN chmod -R a+rX /opt/opentrack/build/install

# Set up runtime environment
ENV QT_X11_NO_MITSHM=1
ENV QT_QPA_PLATFORM=xcb
ENV LD_LIBRARY_PATH=/opt/opentrack/build/install/libexec/opentrack:${ONNXRuntime_DIR}/lib:$LD_LIBRARY_PATH

WORKDIR /opt/opentrack/build/install/bin
USER opentrack

CMD ["./opentrack"]
