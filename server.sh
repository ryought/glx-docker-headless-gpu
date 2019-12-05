#!/bin/bash
docker build -t sim .
docker run --privileged -it --rm --gpus all \
  -v $HOME/lgsvlsimulator-linux64-2019.11:/lg \
  -v $HOME/container-unity3d-2:/home/autoware/.config/unity3d:rw \
  -p 8081:8081 \
  -p 8082:8082 \
  -e USER_ID=$(id -u) \
  --name sim sim

# 8081: noVNC port
# 8082: simulator
