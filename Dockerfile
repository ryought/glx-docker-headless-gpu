FROM ubuntu:16.04

# Make all NVIDIA GPUS visible, but I want to manually install drivers
ARG NVIDIA_VISIBLE_DEVICES=all
# Supress interactive menu while installing keyboard-configuration
ARG DEBIAN_FRONTEND=noninteractive


# (1) Install Xorg and NVIDIA driver inside the container
# Almost same procesure as nvidia/driver https://gitlab.com/nvidia/driver/blob/master/ubuntu16.04/Dockerfile

# (1-1) Install prerequisites
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        build-essential \
        ca-certificates \
        curl \
        wget \
        vim \
        zip \
        unzip \
        git \
        python \
        kmod \
        libc6:i386 \
        pkg-config \
        libelf-dev && \
    rm -rf /var/lib/apt/lists/*

# (1-2) Install xorg server and xinit BEFORE INSTALLING NVIDIA DRIVER.
# After this installation, command Xorg and xinit can be used in the container
RUN apt-get update && apt-get install -y \
        xinit && \
    rm -rf /var/lib/apt/lists/*

# (1-3) Install NVIDIA drivers, including X graphic drivers
# Same command as nvidia/driver, except --x-{prefix,module-path,library-path,sysconfig-path} are omitted in order to make use default path and enable X drivers.
# Driver version must be equal to host's driver
# Install the userspace components and copy the kernel module sources.
ENV DRIVER_VERSION=410.104
# ENV DRIVER_VERSION=440.33.01
RUN cd /tmp && \
    curl -fSsl -O https://us.download.nvidia.com/tesla/$DRIVER_VERSION/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run && \
    sh NVIDIA-Linux-x86_64-$DRIVER_VERSION.run -x && \
    cd NVIDIA-Linux-x86_64-$DRIVER_VERSION* && \
    ./nvidia-installer --silent \
                       --no-kernel-module \
                       --install-compat32-libs \
                       --no-nouveau-check \
                       --no-nvidia-modprobe \
                       --no-rpms \
                       --no-backup \
                       --no-check-for-alternate-installs \
                       --no-libglx-indirect \
                       --no-glvnd-egl-client \
                       --no-glvnd-glx-client \
                       --no-install-libglvnd && \
    mkdir -p /usr/src/nvidia-$DRIVER_VERSION && \
    mv LICENSE mkprecompiled kernel /usr/src/nvidia-$DRIVER_VERSION && \
    sed '9,${/^\(kernel\|LICENSE\)/!d}' .manifest > /usr/src/nvidia-$DRIVER_VERSION/.manifest && \
    rm -rf /tmp/*
                       # --no-glvnd-egl-client \
                       # --no-glvnd-glx-client \
                       # this option cannot be used on driver 440.33.01

# (2) Configurate Xorg
# (2-1) Install some necessary softwares
#
# pkg-config: nvidia-xconfig requires this package
# mesa-utils: This package includes glxgears and glxinfo, which is useful for testing GLX drivers
# x11vnc: Make connection between x11 server and VNC client.
# x11-apps: xeyes can be used to make sure that X11 server is running.
#
RUN apt-get update && apt-get install -y --no-install-recommends \
        mesa-utils \
        x11vnc \
        x11-apps && \
    rm -rf /var/lib/apt/lists/*

# (2-2) Optional vulkan support
# vulkan-utils includes vulkan-smoketest, benchmark software of vulkan API
RUN apt-get update && apt-get install -y --no-install-recommends \
        libvulkan1 vulkan-utils && \
    rm -rf /var/lib/apt/lists/*

# for test
RUN apt-get update && apt-get install -y --no-install-recommends \
        firefox openbox && \
    rm -rf /var/lib/apt/lists/*

# sound driver and GTK library
# ALSA系のエラーがでる時は、pulseaudioをインストールして
# X起動後にpulseaudio --start でdaemonを開始させる。
RUN apt-get update && apt-get install -y --no-install-recommends \
      alsa pulseaudio libgtk2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# novnc
RUN wget https://github.com/novnc/noVNC/archive/v1.1.0.zip && \
  unzip -q v1.1.0.zip && \
  rm -rf v1.1.0.zip

# (2-3) Copy xorg.conf
# use existing one
COPY xorg.conf /etc/X11/xorg.conf

# (3) Run Xorg server + x11vnc + X applications
# see run.sh for details
COPY run.sh /run.sh
CMD ["bash", "/run.sh"]
