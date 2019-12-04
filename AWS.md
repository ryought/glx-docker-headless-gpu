# AWSでやる場合の手順書

## インスタンス起動
g4dn.2xlargeの立ち上げ
ベースAMIは素のubuntu18.04

## インスタンス内準備

- ドライバインストール
    https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/install-nvidia-driver.html
    https://docs.aws.amazon.com/ja_jp/AWSEC2/latest/UserGuide/optimize_gpu.html
    など参照
- dockerのインストール
    utils/install-docker.sh参照

