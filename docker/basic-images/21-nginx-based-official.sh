#!/bin/bash

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
# 基于官方镜像（官方基于：debian:buster-slim）
FROM_IMAGE_NAME="nginx"
FROM_IMAGE_TAG="1.17"

IMAGE_NAME="middleware-basic"
IMAGE_TAG="$FROM_IMAGE_NAME-$FROM_IMAGE_TAG$IMGTAG_DEV"

# == 镜像使用的参数 ==
# if [ "$IMGTAG_DEV" == "-dev" ]; then
#     # 开发阶段，设置很小的值。如果代码里面资源未释放，让db挂掉从而提醒去检查代码
# else
#     # 生产系统要合理设置各个参数
# fi

# 定义配置文件
cat >$DOCKER_WORKDIR/nginx.conf <<EOF

EOF

DFILE_NAME=/tmp/DF-$IMAGE_NAME-$IMAGE_TAG.df
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
#     apt-get install -yq --no-install-recommends locales
#     localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
EOF

# 清理缓存文件
if [ "$IMGTAG_DEV" != "-dev" ]; then
cat >>$DFILE_NAME <<EOF
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
EOF
fi

cat >>$DFILE_NAME <<EOF
     echo "Done!"

# COPY nginx.conf ...

EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
echo "" > $DOCKER_WORKDIR/.dockerignore;
rm $DOCKER_WORKDIR/nginx.conf;
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

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
