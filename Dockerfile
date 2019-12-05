# FROM ubuntu:16.04
FROM ubuntu:18.04


# Make all NVIDIA GPUS visible, but I want to manually install drivers
ARG NVIDIA_VISIBLE_DEVICES=all
# Supress interactive menu while installing keyboard-configuration
ARG DEBIAN_FRONTEND=noninteractive

# Error constructing proxy for org.gnome.Terminal:/org/gnome/Terminal/Factory0: Failed to execute child process dbus-launch (No such file or directory)
# fix by setting LANG https://askubuntu.com/questions/608330/problem-with-gnome-terminal-on-gnome-3-12-2
# to install locales https://stackoverflow.com/questions/39760663/docker-ubuntu-bin-sh-1-locale-gen-not-found
RUN apt-get clean && \
    apt-get update && \
    apt-get install -y locales && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

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
# if you need full ubuntu desktop environment, the line below should be added.
        # ubuntu-desktop \
RUN apt-get update && apt-get install -y \
        xinit && \
    rm -rf /var/lib/apt/lists/*

# (1-3) Install NVIDIA drivers, including X graphic drivers
# Same command as nvidia/driver, except --x-{prefix,module-path,library-path,sysconfig-path} are omitted in order to make use default path and enable X drivers.
# Driver version must be equal to host's driver
# Install the userspace components and copy the kernel module sources.
ENV DRIVER_VERSION=410.129-diagnostic
ENV DRIVER_VERSION_PATH=410.129
RUN cd /tmp && \
    curl -fSsl -O https://us.download.nvidia.com/tesla/$DRIVER_VERSION_PATH/NVIDIA-Linux-x86_64-$DRIVER_VERSION.run && \
    sh NVIDIA-Linux-x86_64-$DRIVER_VERSION.run -x && \
    cd NVIDIA-Linux-x86_64-$DRIVER_VERSION && \
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
    sed '9,${/^\(kernel\|LICENSE\)/!d}' .manifest > /usr/src/nvidia-$DRIVER_VERSION/.manifest
                       # this option cannot be used on newer driver
                       # --no-glvnd-egl-client \
                       # --no-glvnd-glx-client \

# (2) Configurate Xorg
# (2-1) Install some necessary softwares
#
# pkg-config: nvidia-xconfig requires this package
# mesa-utils: This package includes glxgears and glxinfo, which is useful for testing GLX drivers
# x11vnc: Make connection between x11 server and VNC client.
# x11-apps: xeyes can be used to make sure that X11 server is running.
#
# Note: x11vnc in ubuntu18.04 is useless beacuse of stack smashing bug. See below to manual compilation.
RUN apt-get update && apt-get install -y --no-install-recommends \
        mesa-utils \
        x11-apps && \
    rm -rf /var/lib/apt/lists/*

# solution for the `stack smashing detected` issue
# https://github.com/LibVNC/x11vnc/issues/61
RUN apt-get update && apt-get install -y --no-install-recommends \
        automake autoconf libssl-dev xorg-dev libvncserver-dev && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/LibVNC/x11vnc.git && \
    cd x11vnc && \
    ./autogen.sh && \
    make && \
    cp src/x11vnc /usr/bin/x11vnc

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
# download websockify as well
RUN wget https://github.com/novnc/noVNC/archive/v1.1.0.zip && \
  unzip -q v1.1.0.zip && \
  rm -rf v1.1.0.zip && \
  git clone https://github.com/novnc/websockify /noVNC-1.1.0/utils/websockify

# Xorg segfault error
# dbus-core: error connecting to system bus: org.freedesktop.DBus.Error.FileNotFound (Failed to connect to socket /var/run/dbus/system_bus_socket: No such file or directory)
# related? https://github.com/Microsoft/WSL/issues/2016
RUN apt-get update && apt-get install -y --no-install-recommends \
      dbus-x11 \
      libdbus-c++-1-0v5 && \
    rm -rf /var/lib/apt/lists/*

# (3) Run Xorg server + x11vnc + X applications
# see run.sh for details
COPY run.sh /run.sh
CMD ["bash", "/run.sh"]
