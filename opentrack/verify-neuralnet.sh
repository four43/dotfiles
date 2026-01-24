#!/bin/bash

# Verify NeuralNet Tracker Installation
# This script checks that ONNX Runtime and NeuralNet tracker are properly installed

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "OpenTrack NeuralNet Tracker Verification"
echo "=========================================="
echo

echo "1. Checking if container is running..."
if docker ps | grep -q opentrack; then
    echo -e "${GREEN}✓${NC} Container is running"
else
    echo -e "${YELLOW}⚠${NC} Container is not running. Start with: docker compose up"
    exit 1
fi

echo
echo "2. Checking NeuralNet tracker plugin..."
if docker exec opentrack test -f /opt/opentrack/build/install/libexec/opentrack/opentrack-tracker-neuralnet.so; then
    echo -e "${GREEN}✓${NC} NeuralNet tracker plugin found"
    SIZE=$(docker exec opentrack stat -c%s /opt/opentrack/build/install/libexec/opentrack/opentrack-tracker-neuralnet.so)
    echo "   Plugin size: $((SIZE / 1024 / 1024)) MB"
else
    echo -e "${YELLOW}✗${NC} NeuralNet tracker plugin NOT found"
    exit 1
fi

echo
echo "3. Checking ONNX Runtime library..."
if docker exec opentrack test -f /opt/onnxruntime-linux-x64-1.23.2/lib/libonnxruntime.so.1.23.2; then
    echo -e "${GREEN}✓${NC} ONNX Runtime v1.23.2 library found"
    SIZE=$(docker exec opentrack stat -c%s /opt/onnxruntime-linux-x64-1.23.2/lib/libonnxruntime.so.1.23.2)
    echo "   Library size: $((SIZE / 1024 / 1024)) MB"
else
    echo -e "${YELLOW}✗${NC} ONNX Runtime library NOT found"
    exit 1
fi

echo
echo "4. Checking library dependencies..."
if docker exec opentrack ldd /opt/opentrack/build/install/libexec/opentrack/opentrack-tracker-neuralnet.so | grep -q "libonnxruntime.so.1 =>"; then
    echo -e "${GREEN}✓${NC} ONNX Runtime linked correctly"
    docker exec opentrack ldd /opt/opentrack/build/install/libexec/opentrack/opentrack-tracker-neuralnet.so | grep onnxruntime
else
    echo -e "${YELLOW}✗${NC} ONNX Runtime NOT linked"
    exit 1
fi

echo
echo "5. Checking for missing dependencies..."
MISSING=$(docker exec opentrack ldd /opt/opentrack/build/install/libexec/opentrack/opentrack-tracker-neuralnet.so | grep "not found" | wc -l)
if [ "$MISSING" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No missing dependencies"
else
    echo -e "${YELLOW}✗${NC} Found $MISSING missing dependencies:"
    docker exec opentrack ldd /opt/opentrack/build/install/libexec/opentrack/opentrack-tracker-neuralnet.so | grep "not found"
    exit 1
fi

echo
echo "6. Checking ONNX models..."
MODELS=$(docker exec opentrack sh -c "ls /opt/opentrack/build/install/libexec/opentrack/models/*.onnx 2>/dev/null" | wc -l)
if [ "$MODELS" -ge 7 ]; then
    echo -e "${GREEN}✓${NC} Found $MODELS ONNX models"
    echo
    echo "   Available models:"
    docker exec opentrack ls -lh /opt/opentrack/build/install/libexec/opentrack/models/ | grep -v "^total" | grep -v "^d" | awk '{print "   - " $9 " (" $5 ")"}'
else
    echo -e "${YELLOW}✗${NC} Only found $MODELS models (expected 7+)"
    exit 1
fi

echo
echo "=========================================="
echo -e "${GREEN}✓ All checks passed!${NC}"
echo
echo "NeuralNet tracker is ready to use. In OpenTrack:"
echo "1. Select 'NeuralNet head pose estimator' as Input"
echo "2. Click the camera settings icon"
echo "3. Choose your webcam"
echo "4. Select a model (recommended: head-pose-0.4-small-f32.onnx)"
echo "5. Click Start"
echo
echo "Note: The first run may take a few seconds to initialize the neural network."
