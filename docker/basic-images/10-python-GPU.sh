#!/bin/bash
# ============================================================
# 所有gpu环境的python docker的基础镜像
# ============================================================
set -e
BINDIR=$(cd `dirname $0`; pwd)
[ -f /usr/local/bin/fd_utils.sh ] || exit 99
. /usr/local/bin/fd_utils.sh
. $BINDIR/env-for-basic-img.sh

# 如果要构建的OS基础镜像是为了开发使用，那么命令行传入 '-dev'。这种镜像会有ssh, vim等软件
IMGTAG_DEV="$1"
[ "$IMGTAG_DEV" != "-dev" ] && IMGTAG_DEV=""

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
FROM_IMAGE_NAME="nvidia/cuda"
FROM_IMAGE_TAG="10.0-cudnn7-runtime-ubuntu18.04"

IMAGE_NAME="python-basic"
IMAGE_TAG="3.6-GPU-cuda10.0$IMGTAG_DEV"

DFILE_NAME=/tmp/DF-$IMAGE_NAME-$IMAGE_TAG.df
# ----------------- Dockerfile Start -----------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai DEBIAN_FRONTEND=noninteractive

RUN  set -ex && \\
     echo "deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse" > /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list && \\
     apt-get update && \\
# tzdata locales
     apt-get install -y --no-install-recommends tzdata && \\
     ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone && \\
     dpkg-reconfigure -f noninteractive tzdata && \\
     apt-get install -yq --no-install-recommends locales && \\
     localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \\
# python
     mkdir ~/.pip/ && \\
     apt-get install -y --no-install-recommends python3.6 python3-dev python3-pip python3-setuptools && \\
     echo "[global]" > ~/.pip/pip.conf && \\
     echo "index-url = https://mirrors.aliyun.com/pypi/simple/" >> ~/.pip/pip.conf && \\
     pip3 install --upgrade setuptools pip && \\
     pip3 install --no-cache-dir numpy scipy pandas scikit-learn python-dateutil h5py pyyaml && \\
EOF

if [ "$IMGTAG_DEV" == "-dev" ]; then
cat >>$DFILE_NAME <<EOF
# ssh, gcc, vi, git, and so on. only for dev stage!
     apt-get install -yq --no-install-recommends openssh-server gcc net-tools vim wget bzip2 unzip curl git && \\
     mkdir /run/sshd && \\
     echo "root:hrs@6688" | chpasswd && \\
     echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \\
EOF
else
cat >>$DFILE_NAME <<EOF
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
EOF
fi

cat >>$DFILE_NAME <<EOF
# over
     echo "Done!"
WORKDIR /data
ENV LANG=en_US.utf8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8
EOF

if [ "$IMGTAG_DEV" == "-dev" ]; then
cat >>$DFILE_NAME <<EOF
CMD  ["/usr/sbin/sshd", "-D"]
EOF
fi
# ----------------- Dockerfile End  -----------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
echo "" > $DOCKER_WORKDIR/.dockerignore;
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

exit 0
