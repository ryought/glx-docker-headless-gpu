# inside docker script

# 0. generate xorg.conf if not copied
[ ! -e /etc/X11/xorg.conf ] && nvidia-xconfig -a --virtual=$SCREEN_RESOLUTION --allow-empty-initial-configuration --enable-all-gpus --busid $BUSID

# 1. launch X server
Xorg :0 &
sleep 3  # wait for the server gets ready

# 2. start x11 and vnc connection
x11vnc -display :0 -passwd $VNC_PASSWORD -forever &
sleep 3  # wait for the server gets ready

# 3. start simulator
export DISPLAY=:0
./lg/simulator -screen-height 480 -screen-width 640 -screen-quality Beautiful -screen-fullscreen 0
