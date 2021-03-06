#!/bin/bash
# ============================================================
# 所有gpu环境的python docker的基础镜像
# ============================================================
set -e
BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

declare -A ArgDict
while getopts ":v:" arg_opt; do
    [ "$arg_opt" == "?" ] && die "Usage:  `basename $0` [-v 3.6/3.7/3.8]" "WARN"
    ArgDict["$arg_opt"]="$OPTARG"
    # echo "current arg : $arg_opt=$OPTARG"
done
# all cmd args
# echo "ArgDict=${!ArgDict[*]}"
ArchType=""; ArchType=$(get_DockerArchName "${ArchType}"); ArchType_Prefix=${ArchType:+"${ArchType}/"}
Version="${ArgDict["v"]}"; Version=${Version:="3.6"}
echo ; echo_info "Cmd args : ArchType=${ArchType}, Version=${Version}"

# FROM base image
FROM_IMAGE_NAME="nvidia/cuda"
FROM_IMAGE_TAG="10.0-cudnn7-runtime-ubuntu18.04"
confirm_op "FROM base image => \033[33m${FROM_IMAGE_NAME}:${FROM_IMAGE_TAG}\033[0m"

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
IMAGE_NAME="${IMAGE_HEAD}python-basic"
IMAGE_TAG="${Version}-GPU-cuda10.0"

DFILE_NAME=/tmp/DF-$IMAGE_TAG.df
# ----------------- Dockerfile Start -----------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai DEBIAN_FRONTEND=noninteractive

RUN  set -ex && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse" > /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-proposed main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-proposed main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list && \\
     apt-get update && \\
# tzdata locales
     apt-get install -y --no-install-recommends tzdata && \\
     ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone && \\
     dpkg-reconfigure -f noninteractive tzdata && \\
     apt-get install -yq --no-install-recommends locales && \\
     localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \\
# ssh, gcc, vi, git, and so on. only for dev stage!
     apt-get install -yq --no-install-recommends openssh-server gcc net-tools nano unzip curl wget && \\
     mkdir /run/sshd && \\
     echo "root:hrs@6688" | chpasswd && \\
     echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \\
# python TODO: 这种方式安装3.7后，再安装pip时，因为缺少distutils.util而需要装python3-distutils，但这会导致系统被装成了3.6.9
     apt-get install -y --no-install-recommends python${Version} python${Version}-dev && \\
     mkdir ~/.pip/ && \\
     if [ ! -f /usr/bin/python3 ]; then ln -s /usr/bin/python${Version} /usr/bin/python3; fi; [ -f /usr/bin/python3 ] && \\
     echo "[global]" > ~/.pip/pip.conf && \\
     echo "trusted-host = pypi.tuna.tsinghua.edu.cn" >> ~/.pip/pip.conf && \\
     echo "index-url = https://pypi.tuna.tsinghua.edu.cn/simple/" >> ~/.pip/pip.conf && \\
     python3 -m pip install --no-cache-dir -U pip==20.0.2 && \\
     python3 -m pip install --no-cache-dir -U setuptools && \\
     python3 -m pip install --no-cache-dir numpy==1.18.5 scipy pandas scikit-learn python-dateutil h5py pyyaml && \\
# clean
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
# over
     echo "Done!"

WORKDIR /data

ENV LANG=en_US.utf8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8

CMD  ["/usr/sbin/sshd", "-D"]
EOF
# ----------------- Dockerfile End  -----------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
[ -f "$DOCKER_WORKDIR/.dockerignore" ] && rm -f $DOCKER_WORKDIR/.dockerignore || echo "file : $DOCKER_WORKDIR/.dockerignore not exist!"
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

echo_done
echo
exit 0
