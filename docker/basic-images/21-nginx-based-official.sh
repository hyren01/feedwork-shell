#!/bin/bash
set -e
BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

declare -A ArgDict
while getopts ":v:a:" arg_opt; do
    [ "$arg_opt" == "?" ] && die "Usage:  `basename $0` [-v 1.17/1.18 -a arm64v8]" "WARN"
    ArgDict["$arg_opt"]="$OPTARG"
    # echo "current arg : $arg_opt=$OPTARG"
done
# all cmd args
# echo "ArgDict=${!ArgDict[*]}"
ArchType="${ArgDict["a"]}"; ArchType=$(get_DockerArchName "${ArchType}"); ArchType_Prefix=${ArchType:+"${ArchType}/"}
Version="${ArgDict["v"]:="1.17"}"
echo ; echo_info "Cmd args : ArchType=${ArchType}, Version=${Version}"

# 基于官方镜像（官方基于：debian:buster-slim）
FROM_IMAGE_NAME="${ArchType_Prefix}nginx"
FROM_IMAGE_TAG="${Version}"
confirm_op "FROM base image => \033[33m${FROM_IMAGE_NAME}:${FROM_IMAGE_TAG}\033[0m"

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
IMAGE_NAME="${IMAGE_HEAD}${ArchType_Prefix}middleware-basic"
IMAGE_TAG="nginx-$FROM_IMAGE_TAG"

# 定义配置文件
cat >$DOCKER_WORKDIR/nginx.conf <<EOF

EOF

DFILE_NAME=/tmp/DF-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai DEBIAN_FRONTEND=noninteractive

RUN  set -ex && \\
     sed -i 's#http://deb.debian.org#http://mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list && \\
     sed -i 's#http://security.debian.org#http://mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list && \\
     apt-get update && \\
     apt-get install -y --no-install-recommends tzdata && \\
     ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone && \\
     dpkg-reconfigure -f noninteractive tzdata && \\
#     apt-get install -yq --no-install-recommends locales
#     localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
     echo "Done!"

# COPY nginx.conf ...
EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
[ -f "$DOCKER_WORKDIR/.dockerignore" ] && rm -f $DOCKER_WORKDIR/.dockerignore || echo "file : $DOCKER_WORKDIR/.dockerignore not exist!"
[ -f "$DOCKER_WORKDIR/nginx.conf" ] && rm -f $DOCKER_WORKDIR/nginx.conf || echo "file : $DOCKER_WORKDIR/nginx.conf not exist!"
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

echo_done
echo
exit 0

# 启动容器（样例）
# 也可以挂载自己的配置文件： -v $PWD/my.cnf.sample:/etc/mysql/conf.d/my.cnf
CAR_NAME="nginx-temptest"
DATA_DIR="/tmp/nginx/html" && mkdir -p $DATA_DIR
echo "你好, nginx!" > $DATA_DIR/index.html
# LOGS_DIR="/tmp/mysql/logs" && mkdir -p $LOGS_DIR
docker container run -d --name $CAR_NAME \
     -p 30080:80 \
     -v $DATA_DIR:/usr/share/nginx/html:ro \
     middleware-basic:nginx-1.17

# 容器的IP
docker inspect $CAR_NAME | grep IP
# 用临时容器的mysql客户端
docker container run --rm -it middleware-basic:nginx-1.17 bash
# 使用已经创建的容器
# docker container exec -it $CAR_NAME sh -c "exec mysql -h容器的IP -uroot -p123456"
docker container exec -it $CAR_NAME bash

# 查看配置参数
