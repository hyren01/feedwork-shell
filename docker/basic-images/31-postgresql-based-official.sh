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
FROM_IMAGE_NAME="postgres"
FROM_IMAGE_TAG="11.7"

IMAGE_NAME="db-basic"
IMAGE_TAG="pgsql-11.7$IMGTAG_DEV"

# == 镜像使用的参数 ==
if [ "$IMGTAG_DEV" == "-dev" ]; then
    # 开发阶段，设置很小的值。如果代码里面资源未释放，让db挂掉从而提醒去检查代码
    MAX_CONN_NUMS=10
    MEM_BUFFER="8MB"
else
    # 生产系统要合理设置各个参数
    # shared_buffers：
    # windows : 512MB
    # linux : 多数情况下用机器物理内存的25%即可。但是，数值太大了刷盘同步或许会慢？
    # 这里暂时设置为2GB。可以使用pg自带的工具反复测试来找到合理的值：pgbench
    MAX_CONN_NUMS=200
    MEM_BUFFER="2048MB"
fi
PG_CNF_FILE="/etc/postgresql/postgresql.conf"

DFILE_NAME=/tmp/DF-$IMAGE_NAME-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai

# RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
# ENV LANG zh_CN.utf8
# sed -i 's#http://deb.debian.org#http://mirrors.aliyun.com#g' /etc/apt/sources.list
RUN  set -ex && \\
     cp /usr/share/postgresql/postgresql.conf.sample $PG_CNF_FILE && \\
# 修改监听IP
     sed -i "s/^[[:space:]]*#\?[[:space:]]*listen_addresses.*/listen_addresses='*'/" $PG_CNF_FILE && \\
     grep "^listen_addresses='\*'" $PG_CNF_FILE > /dev/null && \\
# 修改最大连接数 原则：max_connections > ( max_wal_senders + superuser_reserved_connections )
     sed -i "s/^[[:space:]]*#\?[[:space:]]*max_connections.*/max_connections=${MAX_CONN_NUMS}/" $PG_CNF_FILE && \\
     grep "^max_connections=${MAX_CONN_NUMS}" $PG_CNF_FILE > /dev/null && \\
# 修改共享内存
     sed -i "s/^[[:space:]]*#\?[[:space:]]*shared_buffers.*/shared_buffers=${MEM_BUFFER}/" $PG_CNF_FILE && \\
     grep "^shared_buffers=${MEM_BUFFER}" $PG_CNF_FILE > /dev/null && \\
# over
     echo "Done!"

WORKDIR /data

EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
echo "" > $DOCKER_WORKDIR/.dockerignore;
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

exit 0
