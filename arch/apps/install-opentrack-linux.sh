#!/bin/bash
# Script to rebuild opentrack with NeuralNet support using yay

set -e

echo "--- Installing ONNX Runtime ---"
# Installing the CPU version for maximum compatibility
# Swap to 'onnxruntime-cuda' if you have an NVIDIA GPU
sudo pacman -S --needed onnxruntime-cuda opencv wine-mono

echo "--- Rebuilding opentrack with new dependencies ---"
# --rebuild: Forces yay to re-download/re-compile even if already installed
# --noconfirm: Skips the manual confirmation prompts
yay -S opentrack --rebuild --noconfirm

echo "--- Success! ---"
echo "Launch opentrack and check the 'Input' dropdown for Neuralnet tracker."