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
!my.cnf
EOF

# 【构建镜像】
# 基于官方镜像（官方基于：debian:buster-slim）
FROM_IMAGE_NAME="mysql"
FROM_IMAGE_TAG="5.7"

IMAGE_NAME="db-basic"
IMAGE_TAG="$FROM_IMAGE_NAME-$FROM_IMAGE_TAG$IMGTAG_DEV"

# == 镜像使用的参数 ==
if [ "$IMGTAG_DEV" == "-dev" ]; then
    # 开发阶段，设置很小的值。如果代码里面资源未释放，让db挂掉从而提醒去检查代码
    MAX_CONN_NUMS=6
    tmp_table_size=""
    max_heap_table_size=""
else
    # 生产系统要合理设置各个参数
    MAX_CONN_NUMS=200
    tmp_table_size=""
    max_heap_table_size=""
fi

# 定义 mysql 配置文件
cat > $DOCKER_WORKDIR/my.cnf <<EOF
[mysqld]
user=mysql
character-set-server=utf8
default_authentication_plugin=mysql_native_password
max_connections=$MAX_CONN_NUMS
default-storage-engine=INNODB
lower_case_table_names=1
max_allowed_packet=32M
# Disabling symbolic-links is recommended to prevent assorted security risks
# symbolic-links=0
skip-name-resolve
# skip-grant-tables
[client]
default-character-set=utf8
[mysql]
default-character-set=utf8
EOF

DFILE_NAME=/tmp/DF-$IMAGE_NAME-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai

COPY my.cnf /etc/mysql/conf.d/

WORKDIR /data

EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
echo "" > $DOCKER_WORKDIR/.dockerignore;
rm $DOCKER_WORKDIR/my.cnf;
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

exit 0

# 启动容器（样例）
# 也可以挂载自己的配置文件： -v $PWD/my.cnf.sample:/etc/mysql/conf.d/my.cnf
CAR_NAME="mysql-temptest"
DATA_DIR="/tmp/mysql/data" && mkdir -p $DATA_DIR
LOGS_DIR="/tmp/mysql/logs" && mkdir -p $LOGS_DIR
docker container run -d -p 33306:3306 --name $CAR_NAME \
     -v $DATA_DIR:/var/lib/mysql \
     -v $LOGS_DIR:/logs \
     -e MYSQL_ROOT_PASSWORD=123456 \
     db-basic:mysql-5.7-dev

# 容器的IP
docker inspect $CAR_NAME | grep IP
# 用临时容器的mysql客户端
docker container run --rm -it db-basic:mysql-5.7-dev sh -c 'exec mysql -h"容器的IP" -uroot -p"123456"'
# 使用已经创建的容器
docker container exec -it $CAR_NAME sh -c "exec mysql -h容器的IP -uroot -p123456"

# 查看配置参数
show variables like '%max_connections%'; 
