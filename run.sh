# inside docker script
trap 'sudo kill $(jobs -p)' EXIT

# 0. generate xorg.conf if not copied
# [ ! -e /etc/X11/xorg.conf ] && nvidia-xconfig -a --virtual=$SCREEN_RESOLUTION --allow-empty-initial-configuration --enable-all-gpus --busid $BUSID
# nvidia-xconfig -a --virtual=800x600 --allow-empty-initial-configuration --enable-all-gpus --busid 0:4:0
BUS_ID=$(nvidia-xconfig --query-gpu-info | grep 'PCI BusID' | sed -r 's/\s*PCI BusID : PCI:(.*)/\1/')
echo $BUS_ID
sudo nvidia-xconfig -a --virtual=1280x720 --allow-empty-initial-configuration --enable-all-gpus --busid $BUS_ID

# 1. launch X server
sudo Xorg :0 &
sleep 1  # wait for the server gets ready

# 2. start x11 and vnc connection
#  --verbose
sudo x11vnc -display :0 -passwd pass -forever -rfbport 5900 &
sleep 2  # wait for the server gets ready

# 2.5 start audio
# this is not required.
# sudo pulseaudio --start
# sleep 2

# 3. start noVNC
sudo /noVNC-1.1.0/utils/launch.sh --vnc localhost:5900 --listen 8081 &
sleep 2

# remove sudo group
# gpasswd -d miyazaki unyo

echo 'running noVNC at http://localhost:8081/vnc.html?host=localhost&port=8081'

# 3. start simulator
export DISPLAY=:0
# # xeyes
# glxgears
# glxinfo
# vulkan
# firefox
# xterm
# openbox &

# launch lgsim and its api server
cd /lg
# ./simulator -p 8082 -screen-height 480 -screen-width 640 -screen-quality Beautiful -screen-fullscreen 0 &
./simulator -p 8082 &
sleep 3
xdotool key Tab
xdotool key Tab
xdotool key Tab
xdotool key Tab
xdotool key Tab
xdotool key Return
sleep 3

# kick api mode
node /simlauncher/control.js

# launch autoware
cd ~/Autoware
. install/setup.bash
roslaunch rosbridge_server rosbridge_websocket.launch &

sleep 5
# run simulation
git clone https://github.com/lgsvl/PythonAPI
cd PythonAPI
pip3 install --user -e .
python3 /api.py

# sleep 10
# echo 'finishing the simulation'
# echo 'uploading rosbag to S3'

# wait
# sudo kill $(jobs -p)
