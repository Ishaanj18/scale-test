#!/bin/bash

echo "Starting Android Emulator Container..."

# Get the GID of the host's kvm group from the mounted device
KVM_GID=$(stat -c '%g' /dev/kvm 2>/dev/null || echo "109")
echo "KVM device GID: $KVM_GID"

# Create or update kvm group with correct GID
if ! getent group kvm > /dev/null; then
    groupadd -g $KVM_GID kvm
else
    # Update existing group GID if different
    CURRENT_GID=$(getent group kvm | cut -d: -f3)
    if [ "$CURRENT_GID" != "$KVM_GID" ]; then
        groupmod -g $KVM_GID kvm
    fi
fi

# Add android user to kvm group
usermod -a -G kvm android

# Verify permissions
echo "KVM permissions:"
ls -la /dev/kvm
echo "Android user groups:"
groups android

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

# Wait for all services to come up
sleep 5

# Show current user (for debug)
echo "Running as: $(whoami)"
id

# Test KVM access
echo "Testing KVM access..."
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "KVM access: OK"
else
    echo "KVM access: FAILED"
    echo "Falling back to software acceleration..."
    ACCEL_FLAGS="-accel tcg"
fi

# Launch emulator as 'android' user with proper environment and group
echo "Launching emulator..."
su - android -c "bash -c '
  export ANDROID_HOME=/opt/android-sdk
  export PATH=\$PATH:\$ANDROID_HOME/emulator:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/cmdline-tools/latest/bin
  export DISPLAY=:99
  cd /home/android

  # Test KVM access as android user
  if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo \"KVM access for android user: OK\"
    ACCEL_FLAGS=\"\"
  else
    echo \"KVM access for android user: FAILED\"
    echo \"Using software acceleration...\"
    ACCEL_FLAGS=\"-accel tcg\"
  fi

  echo \"Emulator starting - this may take a few minutes...\"
  emulator -avd TestDevice \
    -no-boot-anim \
    -gpu swiftshader_indirect \
    -skin 1920x1080 \
    -memory 2048 \
    -cores 2 \
    -netdelay none \
    -netspeed full \
    -verbose \
    -no-metrics \
    \$ACCEL_FLAGS
'"
