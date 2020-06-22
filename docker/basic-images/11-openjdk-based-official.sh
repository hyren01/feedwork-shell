#!/bin/bash

set -e
BINDIR=$(cd `dirname $0`; pwd)
[ -f /usr/local/bin/fd_utils.sh ] || exit 99
. /usr/local/bin/fd_utils.sh
. $BINDIR/env-for-basic-img.sh

JDK_OR_JRE="$1"
if [[ "$JDK_OR_JRE" != "jdk" ]] && [[ "$JDK_OR_JRE" != "jre" ]]; then
    die "first argument must be 'jdk' or 'jre' !"
fi

# 如果要构建的OS基础镜像是为了开发使用，那么命令行传入 '-dev'。这种镜像会有ssh, vim等软件
IMGTAG_DEV="$2"
[ "$IMGTAG_DEV" != "-dev" ] && IMGTAG_DEV=""

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
FROM_IMAGE_NAME="openjdk"
FROM_IMAGE_TAG="8-${JDK_OR_JRE}-slim"

IMAGE_NAME="java-basic"
IMAGE_TAG="${FROM_IMAGE_NAME}-${FROM_IMAGE_TAG}$IMGTAG_DEV"

DFILE_NAME=/tmp/DF-$IMAGE_NAME-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai

RUN  set -ex && \\
     sed -i 's#http://deb.debian.org#http://mirrors.aliyun.com#g' /etc/apt/sources.list && \\
     apt-get update && \\
     ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone \\
     && apt-get install -yq --no-install-recommends locales \\
     && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \\
     && apt-get clean \\
     && rm -rf /var/lib/apt/lists/* 

WORKDIR /data

ENV LANG=en_US.utf8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8

EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
echo "" > $DOCKER_WORKDIR/.dockerignore;
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

exit 0
