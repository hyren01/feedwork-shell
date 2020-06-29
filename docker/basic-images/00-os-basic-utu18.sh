#!/bin/bash
set -e
BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

# FROM base image
FROM_IMAGE_NAME="ubuntu"
FROM_IMAGE_TAG="18.04"
confirm_op "FROM base image => \033[33m${FROM_IMAGE_NAME}:${FROM_IMAGE_TAG}\033[0m"

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
IMAGE_NAME="${IMAGE_HEAD}os-basic"
IMAGE_TAG="ubuntu-18.04"

DFILE_NAME=/tmp/DF-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  TZ=Asia/Shanghai DEBIAN_FRONTEND=noninteractive HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME

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
     dpkg-reconfigure -f noninteractive tzdata \\
     && apt-get install -yq --no-install-recommends locales \\
     && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \\
# ssh, gcc, vi, git, and so on. only for dev stage!
     && apt-get install -yq --no-install-recommends openssh-server gcc nano curl \\
     && mkdir /run/sshd \\
     && echo "root:hrs@6688" | chpasswd \\
     && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \\
     && apt-get clean \\
     && rm -rf /var/lib/apt/lists/* \\
# over
     && echo "Done!"

WORKDIR /data
ENV LANG=en_US.utf8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8
CMD  ["/usr/sbin/sshd", "-D"]
EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
[ -f "$DOCKER_WORKDIR/.dockerignore" ] && rm -f $DOCKER_WORKDIR/.dockerignore || echo "file : $DOCKER_WORKDIR/.dockerignore not exist!"
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

echo_done
echo
exit 0
