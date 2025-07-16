#!/bin/bash

echo "Starting Android Emulator Container..."

# Start virtual display
echo "Starting virtual display..."
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99

# Wait for X server
sleep 3

# Start window manager
echo "Starting window manager..."
fluxbox &

# Start VNC server
echo "Starting VNC server..."
x11vnc -display :99 -nopw -listen localhost -xkb -forever -shared &

# Start noVNC web interface
echo "Starting noVNC web interface..."
cd /opt/noVNC && ./utils/novnc_proxy --vnc localhost:5900 --listen 6080 &

# Wait a bit more for services to initialize
sleep 5

su - android -c "
# Set the full environment for the 'android' user
export ANDROID_HOME=/opt/android-sdk
export PATH=${PATH}:${ANDROID_HOME}/emulator:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/cmdline-tools/latest/bin
export DISPLAY=:99
cd /home/android

echo 'Emulator starting - this may take a few minutes...'
# Now that the PATH is set, this command will be found
emulator -avd TestDevice \
    -no-boot-anim \
    -gpu swiftshader_indirect \
    -skin 1920x1080 \
    -memory 2048 \
    -cores 2 \
    -netdelay none \
    -netspeed full \
    -verbose
"