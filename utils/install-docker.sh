#!/bin/bash
# install docker-ce and nvidia-container-runtime on Debian/Ubuntu
# this requires sudo

# https://nvidia.github.io/nvidia-container-runtime/
curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | \
  sudo apt-key add -
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list
sudo apt-get update
sudo apt-get install nvidia-container-runtime

# https://docs.docker.com/v17.09/engine/installation/linux/docker-ce/ubuntu/#upgrade-docker-ce
curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# add $USER to docker group
# to run without docker 
sudo gpasswd -a $USER docker

# to test (with gpu)
# docker run --gpus all nvidia/cuda nvidia-smi
# or (without gpu)
# docker run hello-world

