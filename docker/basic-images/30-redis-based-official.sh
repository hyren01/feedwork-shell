#!/bin/bash

set -e
BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

declare -A ArgDict
while getopts ":a:v:d:" arg_opt; do
    [ "$arg_opt" == "?" ] && die "Usage:  `basename $0` [-v 3/4/5 -a arm64v8]" "WARN"
    ArgDict["$arg_opt"]="$OPTARG"
    # echo "current arg : $arg_opt=$OPTARG"
done
# all cmd args
# echo "ArgDict=${!ArgDict[*]}"
ArchType="${ArgDict["a"]}"; ArchType=$(get_DockerArchName "${ArchType}"); ArchType_Prefix=${ArchType:+"${ArchType}/"}
Version="${ArgDict["v"]}"; Version=${Version:="11"}
echo ; echo_info "Cmd args : ArchType=${ArchType}, Version=${Version}"

# FROM base image
FROM_IMAGE_NAME="${ArchType_Prefix}redis"
FROM_IMAGE_TAG="${Version}"
confirm_op "FROM base image => \033[33m${FROM_IMAGE_NAME}:${FROM_IMAGE_TAG}\033[0m"

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
IMAGE_NAME="${IMAGE_HEAD}${ArchType_Prefix}kvdb-basic"
IMAGE_TAG="redis-$FROM_IMAGE_TAG"

DFILE_NAME=/tmp/DF-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai DEBIAN_FRONTEND=noninteractive

RUN  set -ex && \\
     sed -i 's#http://deb.debian.org#http://mirrors.aliyun.com#g' /etc/apt/sources.list && \\
     apt-get update && \\
     apt-get install -y --no-install-recommends tzdata && \\
     ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone && \\
     dpkg-reconfigure -f noninteractive tzdata && \\
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
     echo "Done!"

# COPY ... ...
EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
[ -f "$DOCKER_WORKDIR/.dockerignore" ] && rm -f $DOCKER_WORKDIR/.dockerignore || echo "file : $DOCKER_WORKDIR/.dockerignore not exist!"
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

echo_done
echo
exit 0

# 启动容器（样例）
# 也可以挂载自己的配置文件： -v $PWD/my.cnf.sample:/etc/mysql/conf.d/my.cnf
CAR_NAME="redis-temptest"
DATA_DIR="/tmp/redis/data" && mkdir -p $DATA_DIR
# LOGS_DIR="/tmp/mysql/logs" && mkdir -p $LOGS_DIR
docker container run -d --name $CAR_NAME_HRS_REDIS \
     -v $DATA_DIR:/data \
     kvdb-basic:redis-3

# 容器的IP
docker inspect $CAR_NAME | grep IP
# 用临时容器的mysql客户端
docker container run --rm -it hrs/kvdb-basic:redis-3 bash
# 使用已经创建的容器
# docker container exec -it $CAR_NAME sh -c "exec mysql -h容器的IP -uroot -p123456"
docker container exec -it $CAR_NAME bash

# 查看配置参数
