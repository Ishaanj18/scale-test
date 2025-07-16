# syntax=docker/dockerfile:1
# IMPORTANT: This image must be built for linux/amd64, not arm64 (Apple Silicon)!
# Use: docker build --platform=linux/amd64 ...
# Or:  docker-compose build --no-cache --platform=linux/amd64
# Simple Android Emulator Container for Digital Signage Testing
# FINAL VERSION: Correctly places the symlink fix.
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Android SDK environment
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator

# Display settings
ENV DISPLAY=:99

# Install all dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb x11vnc fluxbox \
    openjdk-17-jdk \
    wget unzip curl git \
    supervisor \
    libasound2 libdbus-1-3 libgl1 libnss3 libpulse0 libx11-xcb1 \
    libxcomposite1 libxcursor1 libxi6 libxrandr2 libxrender1 libxtst6 \
    libfontconfig1 libncurses5 libc-bin \
    && ls -l /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 \
    && rm -rf /var/lib/apt/lists/*

# THE FIX: Create a symlink for the dynamic loader where the emulator expects it.
RUN mkdir -p /lib64 && ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Ensure kvm group exists with correct GID for KVM passthrough
RUN groupadd -g 109 kvm
RUN useradd -m -s /bin/bash android
RUN usermod -aG kvm android

# --- Component Installation ---
USER root
RUN mkdir -p ${ANDROID_SDK_ROOT} && chown -R android:android ${ANDROID_SDK_ROOT}
USER android
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools
USER root
RUN cd ${ANDROID_SDK_ROOT}/cmdline-tools && \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O c.zip && \
    unzip -q c.zip && mv cmdline-tools latest && rm c.zip
RUN wget -q https://dl.google.com/android/repository/emulator-linux_x64-13610412.zip -O /tmp/e.zip && \
    echo "2fe2b56fe93ce75e1d478a40162131381d911c355efeaedb54dd1e0d0897a5cf  /tmp/e.zip" | sha256sum -c - && \
    unzip -q /tmp/e.zip -d ${ANDROID_SDK_ROOT}/ && rm /tmp/e.zip
RUN echo '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><ns2:repository xmlns:ns2="http://schemas.android.com/repository/android/common/01" xmlns:ns3="http://schemas.android.com/repository/android/generic/01"><license id="android-sdk-license" type="text">Terms and Conditions</license><localPackage path="emulator" obsolete="false"><type-details xsi:type="ns3:genericDetailsType" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"/><revision><major>35</major><minor>6</minor><micro>11</micro></revision><display-name>Android Emulator</display-name><uses-license ref="android-sdk-license"/></localPackage></ns2:repository>' > ${ANDROID_SDK_ROOT}/emulator/package.xml
RUN chown -R android:android ${ANDROID_SDK_ROOT}
RUN cp -r ${ANDROID_SDK_ROOT}/cmdline-tools/latest ${ANDROID_SDK_ROOT}/cmdline-tools/tools

# --- Configuration ---
USER android
WORKDIR /home/android
RUN yes | ${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin/sdkmanager --licenses
RUN ${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin/sdkmanager \
    "platform-tools" \
    "system-images;android-30;google_apis_playstore;x86_64"
RUN echo "no" | avdmanager create avd \
    --force \
    --name "TestDevice" \
    --package 'system-images;android-30;google_apis_playstore;x86_64' \
    --abi 'google_apis_playstore/x86_64'

# --- Final Setup ---
USER root
RUN git clone https://github.com/novnc/noVNC.git /opt/noVNC && \
    git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports and run
EXPOSE 5900 6080 5554 5555
CMD ["/start.sh"]