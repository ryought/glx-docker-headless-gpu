# inside docker script

# 0. generate xorg.conf if not copied
# [ ! -e /etc/X11/xorg.conf ] && nvidia-xconfig -a --virtual=$SCREEN_RESOLUTION --allow-empty-initial-configuration --enable-all-gpus --busid $BUSID
# nvidia-xconfig -a --virtual=800x600 --allow-empty-initial-configuration --enable-all-gpus --busid 0:4:0
BUS_ID=$(nvidia-xconfig --query-gpu-info | grep 'PCI BusID' | sed -r 's/\s*PCI BusID : PCI:(.*)/\1/')
echo $BUS_ID
nvidia-xconfig -a --virtual=1280x720 --allow-empty-initial-configuration --enable-all-gpus --busid $BUS_ID

# 1. launch X server
Xorg :0 &
sleep 2  # wait for the server gets ready

# 2. start x11 and vnc connection
x11vnc -display :0 -passwd pass -forever -rfbport 5900 &
sleep 2  # wait for the server gets ready

# 2.5 start audio
pulseaudio --start
sleep 2

# 3. start noVNC
/noVNC-1.1.0/utils/launch.sh --vnc localhost:5900 --listen 8081 &
sleep 2

# 3. start simulator
export DISPLAY=:0
# ./lg/simulator -screen-height 480 -screen-width 640 -screen-quality Beautiful -screen-fullscreen 0
# ./lg/simulator -p 8082
# # xeyes
# glxgears
# glxinfo
# vulkan
# firefox
# xterm
openbox
