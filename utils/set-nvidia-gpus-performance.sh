#!/bin/bash
# for Nvidia Tesla T4 on AWS G4 instances
# https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/optimize_gpu.html
sudo nvidia-persistenced
sudo nvidia-smi --auto-boost-default=0
sudo nvidia-smi -ac 5001,1590
