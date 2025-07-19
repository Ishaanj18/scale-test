# syntax=docker/dockerfile:1

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Android SDK environment
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator
ENV DISPLAY=:99

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb x11vnc fluxbox \
    openjdk-17-jdk \
    wget unzip curl git \
    supervisor \
    libasound2 libdbus-1-3 libgl1 libnss3 libpulse0 libx11-xcb1 \
    libxcomposite1 libxcursor1 libxi6 libxrandr2 libxrender1 libxtst6 \
    libfontconfig1 libncurses5 libc-bin \
 && rm -rf /var/lib/apt/lists/*

# Symlink fix for Android Emulator dynamic linker
RUN mkdir -p /lib64 && ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Create android user - we'll add to kvm group at runtime
RUN useradd -m -s /bin/bash android

# Set up SDK directories with correct ownership
RUN mkdir -p ${ANDROID_SDK_ROOT} \
 && chown -R android:android ${ANDROID_SDK_ROOT}

# Install Android Command Line Tools
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
 && cd ${ANDROID_SDK_ROOT}/cmdline-tools \
 && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O c.zip \
 && unzip -q c.zip \
 && mv cmdline-tools latest \
 && rm c.zip

# Install Android Emulator
RUN wget -q https://dl.google.com/android/repository/emulator-linux_x64-13610412.zip -O /tmp/e.zip \
 && echo "2fe2b56fe93ce75e1d478a40162131381d911c355efeaedb54dd1e0d0897a5cf  /tmp/e.zip" | sha256sum -c - \
 && unzip -q /tmp/e.zip -d ${ANDROID_SDK_ROOT}/ \
 && rm /tmp/e.zip

# Emulator package metadata fix
RUN echo '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><ns2:repository xmlns:ns2="http://schemas.android.com/repository/android/common/01" xmlns:ns3="http://schemas.android.com/repository/android/generic/01"><license id="android-sdk-license" type="text">Terms and Conditions</license><localPackage path="emulator" obsolete="false"><type-details xsi:type="ns3:genericDetailsType" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"/><revision><major>35</major><minor>6</minor><micro>11</micro></revision><display-name>Android Emulator</display-name><uses-license ref="android-sdk-license"/></localPackage></ns2:repository>' > ${ANDROID_SDK_ROOT}/emulator/package.xml

# Duplicate cmdline-tools to 'tools' (some SDK commands rely on this legacy path)
RUN cp -r ${ANDROID_SDK_ROOT}/cmdline-tools/latest ${ANDROID_SDK_ROOT}/cmdline-tools/tools

# Change ownership of SDK
RUN chown -R android:android ${ANDROID_SDK_ROOT}

# Switch to android user
USER android
WORKDIR /home/android

# Accept SDK licenses
RUN yes | ${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin/sdkmanager --licenses

# Install required tools and system image (x86_64 version)
RUN ${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin/sdkmanager \
    "platform-tools" \
    "system-images;android-30;google_apis_playstore;x86_64"

# Create AVD
RUN echo "no" | avdmanager create avd \
    --force \
    --name "TestDevice" \
    --package 'system-images;android-30;google_apis_playstore;x86_64' \
    --abi 'google_apis_playstore/x86_64'

# Switch back to root to configure entrypoint and VNC
USER root

# Setup noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/noVNC \
 && git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify

# Add launcher script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose ports
EXPOSE 5900 6080 5554 5555

# Run script
CMD ["/start.sh"]
