# inside docker script
trap 'kill $(jobs -p)' EXIT

# 0. generate xorg.conf
BUS_ID=$(nvidia-xconfig --query-gpu-info | grep 'PCI BusID' | sed -r 's/\s*PCI BusID : PCI:(.*)/\1/')
nvidia-xconfig -a --virtual=$RESOLUTION --allow-empty-initial-configuration --enable-all-gpus --busid $BUS_ID

# 1. launch X server
Xorg :0 &
sleep 1  # wait for the server gets ready

# 2. start x11 and vnc connection
# to inspect logs in detail, use --verbose
x11vnc -display :0 -passwd $VNCPASS -forever -rfbport 5900 &
sleep 2  # wait for the server gets ready

# 2.5 start audio
# this is not required.
# pulseaudio --start
# sleep 2

# 3. start noVNC
/noVNC-1.1.0/utils/launch.sh --vnc localhost:5900 --listen 8081 &
sleep 2

echo 'running noVNC at http://localhost:8081/vnc.html?host=localhost&port=8081'

# 3. start simulator
export DISPLAY=:0
openbox
