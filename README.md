# Run Unity apps in docker container on headless Nvidia GPU server

OpenGLやGLXなどを使ってグラフィック用途でGPUを使うアプリケーションを、画面のないheadlessサーバー上で、しかもDocker内で動かす方法のまとめ。

具体的には、Unityで作られたソフト本体の自動テスト環境やそれを使ったCI環境を、GPUインスタンスを含んだkubernetesクラスタ上に構築したい時に使える。

## Background

自動テストサーバーを作るために、 https://github.com/lgsvl/simulator をKubernetes上で動かしたかった。

ECSもGPUインスタンスをサポートし始めたので、Docker内でグラフィック系アプリケーションをGPU機能込みで閉じ込めたい需要は割とあると思うので、まとめておく。

## Method
とりあえず使いたい人向けに手順をまず書く。

### 1. Google Cloud Platform Compute Engineのインスタンスのセットアップ
GPUインスタンス上で、GPUのドライバとnvidia-docker2をインストールする。

まず使うVMをGCP Compute Engineで立ち上げる。基本的にはNVIDIA GPUが搭載されているインスタンスを立ち上げて、GPUドライバ+nvidia-docker2をインストールすれば良いが、Marketplaceから入手できるDeep Learning VMをdeployするとインストール済みイメージが載った状態のVMにアクセスできる。

ここで使ったのは

- Deep Learning VM by Google
- n1-highmem-2
- 1 x NVIDIA Tesla T4
- 100GB HDD
- Tensorflow 1.14 frameworkを有効化(これはどれでも良さそう)
- nvidiaドライバ込み

それ以外は標準のままのインスタンス。us-west1-bに立ち上げた。起動時にwarningが出るが気にしない。ブラウザ上で設定したが、同様のコマンドは以下。

```
gcloud compute --project=$PROJECT_NAME create $INSTANCE_NAME \
  --zone=us-west1-b \
  --machine-type=n1-highmem-2 \
  --subnet=default \
  --network-tier=PREMIUM \
  --metadata=framework=TensorFlow:1.13,google-logging-enable=0,google-monitoring-enable=0,install-nvidia-driver=True,status-config-url=https://runtimeconfig.googleapis.com/v1beta1/projects/sever-rendering/configs/tensorflow-1-config,status-uptime-deadline=600,status-variable-path=status,title=TensorFlow/Keras/Horovod.CUDA10.0,version=27 \
  --maintenance-policy=TERMINATE \
  --service-account=471732791036-compute@developer.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/cloud.useraccounts.readonly,https://www.googleapis.com/auth/cloudruntimeconfig \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --tags=deeplearning-vm \
  --image=tf-1-14-cu100-20190619 \
  --image-project=click-to-deploy-images \
  --boot-disk-size=100GB \
  --boot-disk-type=pd-standard \
  --boot-disk-device-name=tensorflow-1-vm-1 \
  --labels=goog-dm=tensorflow-1
```

ssh port forwardを使うので、sshクライアントからログインできるようにセットアップしておく。(コンソールからssh鍵を登録する。`ssh-keygen -t rsa -C "$USERNAME" -b 4096 -f ~/.ssh/$KEYNAME` コメントのユーザー名に指定したユーザーでしかログインできないので注意。)

sshログインして`nvidia-smi`を実行して、GPUが検出されることと、入っているドライババージョンを確認
上のVMでは、Tesla T4とドライババージョン410.104が入っていた。


### 2. container立ち上げ
X11サーバーとアプリケーションの入ったdocker containerをビルド、立ち上げる。

```
nvidia-docker build -t x11-GL-docker .
docker run --runtime=nvidia --privileged -it --rm \
  -p 5900:5900 \  # or --net=host
  -e BUSID=PCI:0:4:0 \
  -e SCREEN_RESOLUTION=1280x1024 \
  -e VNC_PASSWORD=passpass \
  -v /home/ryonakabayashi/x11-docker/lgsvlsimulator-linux64-2019.05:/lg \
  --name x11-GL-docker x11-GL-docker
```

run.shがdocker内で実行される。

5900ポートはVNC用。またホストマシンに一度ログインして、`nvidia-xconfig --query-gpu-info`を実行し、BUSIDを控えておく。

### 3. port forwarding, VNC connection
docker内で起動しているVNCサーバーに、ssh経由で接続する。

```
ssh -i "$KEYFILE" -L 5900:localhost:5900 $USERNAME@$GCP_PUBLIC_IP -N &
```

でトンネルを作り、VNCクライアント(macならFinder)で`vnc://localhost:5900`に接続する。

リモートのdocker内でレンダリングした結果が手元のmacbookで確認できる環境がこれで整った。

## 何をしているか
2つの要素が組み合わさってできている。

- (A) headless GPU server上でGLXアプリを動かす
	
	GPUを使える仮想ディスプレイを作る。ソフトウェアレンダリングで十分な場合は、`xorg xvfb x11vnc`などで仮想ディスプレイ環境を作れるが、GPUを使いたい場合はNVIDIAドライバの機能を使う必要がある。
- (B) docker上でX11サーバーを動かす

	ポピュラーな`DISPLAY` `/tmp/.X11-unix`を共有する方法ではなく、Xorgをコンテナ内で動かす方法。
- (A+B) headless GPU server上のdocker上でX11サーバーとGLXアプリを動かす

	上の2つを合わせれば完成。

順番に解説する。

### (A) run GLX apps on headless NVIDIA GPU server

これに関しては解説がいろいろある。

- [NVIDIA GPUで作るHeadless X11 Linux](https://www.slideshare.net/T_S/headless-x11-demo)
- [Setting up a HW accelerated desktop on AWS G2 instances](https://medium.com/@pigiuz/setting-up-a-hw-accelerated-desktop-on-aws-g2-instances-4b58718a4541)
- [EC2\(g2\.2xlarge\)でOpenGLを使う方法 \- ⊥=⊥](http://xanxys.hatenablog.jp/entry/2014/05/17/135932)
- [How to run Unity on Amazon Cloud or without Monitor](https://towardsdatascience.com/how-to-run-unity-on-amazon-cloud-or-without-monitor-3c10ce022639)
- [VirtualGL \| Documentation / Headless nVidia Mini How\-To](https://virtualgl.org/Documentation/HeadlessNV)
- [Running without display and selecting GPUs \- CARLA Simulator](https://carla.readthedocs.io/en/latest/carla_headless/)

大まかな手順としては

- Xorg, Nvidia Driverのインストール
- XorgがGPUを使うようにconfを編集

`nvidia-xconfig`を使うと、headless環境で仮想displayを使うためのXorg向けの設定を出力できる。しかしコマンド自体のオプションのマニュアルが不足しているので、release noteを読んで確認する必要がある。

今回はTesla T4を使う。`nvidia-xconfig --query-gpu-info`を見るとBUS idはPCI:0:4:0だったので

```
nvidia-xconfig \
  -a \
  --virtual=1280x1024 \  # 仮想スクリーンの解像度
  --allow-empty-initial-configuration \ # ディスプレイがなくてもXサーバーを起動する
  --enable-all-gpus \  # GPUを有効化
  --busid PCI:0:4:0  # GPUを見つけられるようにBUSIDを指定しておく
```

を実行した。これで出てきた/etc/X11/xorg.confはきちんと動いた。

`--use-display-device=None`をつけるという記述があるが、[Version 410\.104\(Linux\)/412\.29\(Windows\) :: NVIDIA Tesla Documentation](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-410-104/index.html) によると410.104からサポートされなくなったらしく、つけると起動しなくなるので注意。

詳細についてはrepositoryの記述も読んでください。




### (B) X on Docker
X11 GUIアプリケーションをdocker内で動かしたい時、いくつか選択肢がある。

1. hostのx11 socketの共有 or hostで建てているx serverのアドレスを環境変数DISPLAYで渡す
	
	docker run時に`-e DISPLAY=$DISPLAY`とか`-v /tmp/.X11-unix:/tmp/.X11-unix`とかを指定するのはこちらのアプローチ。やり方については検索すると出てくるので割愛。
	
	x11 clientだけをcontainer内で動かし、host上で動いているx11 serverに接続して描画してもらう。dockerからは描画命令だけが来るので、例えばGPUを使って実際に描画するのはx11 server側、つまりcontainer外になる。それ以前に、デスクトップ環境を作っていないサーバー上で動かす場合、そのhost上でまずX11サーバーをセットアップする必要がある。
	
	この方法でも、「ローカルのデスクトップ環境上で動かすが、ホストの環境を汚さないためにdocker内でGUIアプリを使いたい」場合や、「サーバーだけど直にX11をセットアップするのを厭わない」場合は十分。
3. docker内にx11 serverも建てる
	
	x11 client, server共にdocker内で動いている。このままでは画面が見えないが、VNCやスクリーンショットの形で出力する。この場合は、実際に描画処理をしているのもコンテナになる。
	
	- kubernetesやECSなどのコンテナベースのサービスを使っていて、Dockerコンテナの外側の環境に触れない場合
	- host上にX11サーバーをセットアップするのが面倒/できない場合

	だと、コンテナ内で完結する2の方法を取らざるを得なくなる。
	
	例えば [DockerでXサーバを動かしてGUIを直接表示する \- くんすとの備忘録](https://kunst1080.hatenablog.com/entry/2018/03/18/225102) はこのアプローチを取っている。基本的にはコンテナ内にXserverとXclientを両方インストールし実行する。
	

### (A+B) GPU-enabled X server on Docker
普通のXアプリなら上の手順で良いが、OpenGLなどグラフィック用途でGPUを使うアプリケーションの場合、

1. hostのx11 socket共有
	
	[NVIDIA Docker で HW accelerated な OpenGL\(GLX\) を動かす\(2019 年版\) \- Qiita](https://qiita.com/syoyo/items/22a0db4d49495020f1bd) でも触れられているように、 [nvidia/opengl \- Docker Hub](https://hub.docker.com/r/nvidia/opengl) などを使う方法がある。繰り返しになるがこの場合だとレンダリングしているのはホスト側になる。
2. docker内にx11 serverも建てる

	この場合の手順について書かれた文章はほとんど見つけることができなかった。今回はこれをやりたい。
	
	コンテナ内にインストールされたXserverがGPUを扱えるように、X用のドライバをインストールする必要がある。

#### グラフィック系ドライバのdocker内へのインストール
docker内でNVIDIA GPUを扱いたいときは、nvidia-docker2を使うのが普通。これはホストのGPUのデバイスファイルとそのドライバをコンテナと共有し、GPUをコンテナ内側でも使えるようにする技術だが、公式にはCUDA系やOpenGLの一部のみをサポートしていて、グラフィック系のGLX・Xorgからのレンダリング・vulkan等に対応していない( https://github.com/NVIDIA/nvidia-docker/issues/631 )ため、XorgがNVIDIA-GPUを使うためのドライバやGLXのextensionはコンテナと共有されない。

なので、nvidia-docker2の機能でGPUのデバイスファイルを使えるようにし、ドライバはコンテナ内部で1からインストールすることでGLXをコンテナ内で使えるようにできた。

コンテナ内部でドライバをインストールするDockerfileとして、公式の [nvidia/driver \- Docker Hub](https://hub.docker.com/r/nvidia/driver)  とその解説wiki [Driver containers \(Beta\) · NVIDIA/nvidia\-docker Wiki](https://github.com/NVIDIA/nvidia-docker/wiki/Driver-containers-(Beta)) がある。これはNVIDIAのドライバを公式からダウンロードして、インストールスクリプトを実行しているDockerfileだが、前述のようにX系のドライバをインストールを省略している。 https://gitlab.com/nvidia/driver/blob/master/ubuntu16.04/Dockerfile#L43 を見ると

```
                       --x-prefix=/tmp/null \
                       --x-module-path=/tmp/null \
                       --x-library-path=/tmp/null \
                       --x-sysconfig-path=/tmp/null \
```

そこでXorgをインストールした後、ドライバインストール時にこのオプションをきちんと設定して、X用のグラフィックドライバをインストールさせる。これが終われば、ホストのGPUサーバー上でXorgを動かすのと全く同様に、dockerコンテナ内でXorgを(GPU込みで)動かすことができるようになる。

あとは(A)と同じで、(A)のコマンドで作ったxorg.confをコンテナ内に設置して、`Xorg &`でサーバーを走らせれば動く。


## 各種ソフトウェア

### xorg
X11サーバーの1つの実装。

`Xorg :0`とするとサーバーが立ち上がる。

例えば`x11-apps`を入れて`DISPLAY=:0 xeyes`とすると目玉のテストアプリケーションが立ち上がる。

[UbuntuでNVIDIAのディスプレイドライバが動作しない場合のチェック項目 \- Qiita](https://qiita.com/gm3d2/items/8346c76961d3fdb257b7) が参考になる。

lspci | grep NVIDIA

- 設定ファイル /etc/X11/xorg.conf
- ログファイル /var/log/Xorg.0.log
- /usr/lib/xorg/modules/drivers ドライバ
- /usr/lib/xorg/modules/extensions glxのエクステンションなど


### テスト用X11アプリ
- xeyes Xサーバーが動いているか？
- glxgears, glxinfo GLXが使えるか？
- vulkan-smoketest vulkanが使えるか？

### x11vnc
起動しているx11 serverの画面をそのままvncで飛ばすソフトウェア。実際のdisplayが繋がっている場合はその画面が、仮想displayの場合はその中身が転送される。

ずっと起動しておく -forever

ポート変更 x11vnc -rfbport 5566 

### virtualGL
- 公式 https://virtualgl.org/About/Background
- わかりやすいarchlinuxの解説 https://wiki.archlinux.jp/index.php/VirtualGL

実際にアプリケーションを表示したいXサーバーのアドレスを`:0`、GPUにアクセスできるXサーバーのアドレスを`:1`とする。

```
DISPLAY=:0 VGL_DISPLAY=:1 vglrun glxgears
```

とした場合、アプリケーションのレンダリング命令が`:1`に行き、そのレンダリング結果が画像としてキャプチャされ、`:0`に送られる。これは通常通り

```
DISPLAY=:0 glxgears
```

とした時に、GPUにアクセスできないXサーバー(例えばこれはssh -Xで転送されたクライアントのXサーバーなど)側にレンダリング命令が来てGPUを活用できない状況をパフォーマンス面で改善できるが、実際に`:0`から見える結果は全く同じになる。

### xvfb
仮想ディスプレイを作るソフト。
ただしGPUは使わない。ソフトレンダリングのみならこれで十分。

### nvidia-xconfig
Xサーバーがnvidia gpuを使えるように

nvidia-xconfig --query-gpu-info


### X周りの要素技術についてのまとめ
[おっさんエンジニアの実験室: 12月 2016](http://ossan-engineer.blogspot.com/2016/12/)

