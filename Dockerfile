# ACSI2STM standardized build environment
#
# Tested with podman, docker should work with the exact same commands.
#
# How to generate a build:
#
#    podman build -t acsi2stm .
#    podman run --rm --mount type=bind,source=$PWD,target=/acsi2stm -t acsi2stm
#
# How to cleanup images:
#
#    podman image rm acsi2stm
#    podman image prune
#

# Use a lightweight debian base image
FROM debian:stable-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/.arduino15/bin:${PATH}"

# Install prerequisites
RUN apt-get update && apt-get install -y \
    curl \
    zip \
    unzip \
    git \
    ca-certificates \
    xxd \
    mtools \
    dos2unix

# Install vasm
RUN curl -fsSL http://www.ibaug.de/vbcc/vbcc_linux_x64.tar.gz | tar -C /usr/local/bin --strip-components 2 -xvz vbcc/bin/vasmm68k_mot && \
    chmod +x /usr/local/bin/vasmm68k_mot

# Download Arduino
RUN curl -fsSL https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Linux_64bit.tar.gz | tar -C /usr/local/bin -xvz && \
    chmod +x /usr/local/bin/arduino-cli

# Install Arduino
RUN arduino-cli config init && \
    arduino-cli core update-index && \
    arduino-cli lib update-index

# Install Arduino libraries
RUN arduino-cli core install arduino:mbed_rp2040 && \
    arduino-cli lib install "SdFat - Adafruit Fork"

# Install Arduino_STM32
RUN mkdir -p /root/Arduino/hardware/Arduino_STM32 && \
    curl -fsSL https://github.com/rogerclarkmelbourne/Arduino_STM32/archive/refs/heads/master.tar.gz | tar -C /root/Arduino/hardware/Arduino_STM32 --strip-components 1 -xvz

# Set the working directory
# WARNING: this must be mounted to the acsi2stm source directory using --mount type=bind.
WORKDIR /acsi2stm

# Start build command by default
CMD ["./build_release.sh"]
