nvidia-docker build -t x11-GL-docker .
docker run --runtime=nvidia --privileged -it --rm \
  -p 5900:5900 \  # or --net=host
  -e BUSID=PCI:0:4:0 \
  -e SCREEN_RESOLUTION=1280x1024 \
  -e VNC_PASSWORD=passpass \
  -v $HOME/lgsvlsimulator-linux64-2019.05:/lg \
  --name x11-GL-docker x11-GL-docker
