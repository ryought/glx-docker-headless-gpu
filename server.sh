docker build -t sim .

docker run --privileged -it --rm --gpus all \
  -v $HOME/lgsvlsimulator-linux64-2019.11:/lg \
  -v $HOME/container-unity3d:/root/.config/unity3d \
  -p 8081:8081 \
  -p 8082:8082 \
  --name sim sim

# 8081: noVNC port
# 8082: simulator
