#!/bin/bash
set -e
BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

declare -A ArgDict
while getopts ":a:v:d:" arg_opt; do
    [ "$arg_opt" == "?" ] && die "Usage:  `basename $0` [-v 11/12 -a arm64v8 -d dev]" "WARN"
    ArgDict["$arg_opt"]="$OPTARG"
    # echo "current arg : $arg_opt=$OPTARG"
done
# all cmd args
# echo "ArgDict=${!ArgDict[*]}"
ArchType="${ArgDict["a"]}"; ArchType=$(get_DockerArchName "${ArchType}"); ArchType_Prefix=${ArchType:+"${ArchType}/"}
Version="${ArgDict["v"]}"; Version=${Version:="11"}
DevProd="${ArgDict["d"]}"
echo ; echo_info "Cmd args : ArchType=${ArchType}, Version=${Version}, DevProd=${DevProd}"

# FROM base image
FROM_IMAGE_NAME="${ArchType_Prefix}postgres"
FROM_IMAGE_TAG="${Version}"
confirm_op "FROM base image => \033[33m${FROM_IMAGE_NAME}:${FROM_IMAGE_TAG}\033[0m"

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
IMAGE_NAME="${IMAGE_HEAD}${ArchType_Prefix}db-basic"
IMAGE_TAG="pgsql-${FROM_IMAGE_TAG}$DevProd"

# == 镜像使用的参数 ==
# DevProd: 这个命令行参数目前的用法没有意思。因为下面这些参数，可以在启动容器的时候设置！
if [ "$DevProd" == "dev" ]; then
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

DFILE_NAME=/tmp/DF-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai

# RUN localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8
# ENV LANG zh_CN.utf8
# sed -i 's#http://deb.debian.org#http://mirrors.aliyun.com#g' /etc/apt/sources.list
RUN  set -ex && \\
     sed -i 's#http://deb.debian.org#http://mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list && \\
     sed -i 's#http://security.debian.org#http://mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list && \\
     apt-get update && \\
     apt-get install -yq --no-install-recommends procps nano curl && \\
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
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

# WORKDIR /data

EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
[ -f "$DOCKER_WORKDIR/.dockerignore" ] && rm -f $DOCKER_WORKDIR/.dockerignore || echo "file : $DOCKER_WORKDIR/.dockerignore not exist!"
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

echo_done
echo
exit 0

# 启动容器（样例）
Image="hrs/arm64v8/db-basic"
Tag="pgsql-11"
CAR_NAME="hrs-pgsql-tmptest"
DATA_DIR="/tmp/pgsql/pgdata" && mkdir -p $DATA_DIR
docker container run -d -p 35432:5432 --name $CAR_NAME \
     -v $DATA_DIR:/var/lib/postgresql/data \
     -e POSTGRES_PASSWORD=112233 \
     ${Image}:${Tag} -c 'shared_buffers=256MB' -c 'max_connections=15'
# 启动时用镜像里面的配置文件
     ${Image}:${Tag} -c 'config_file=/etc/postgresql/postgresql.conf'

# 容器的IP
docker inspect $CAR_NAME | grep IPAddress
# 用临时容器的psql客户端
docker container run --rm -it ${Image}:${Tag} psql -U postgres -h 容器的IP
docker container run --rm -it ${Image}:${Tag} sh -c 'exec psql -U postgres -h 容器的IP'
# 使用已经创建的容器
docker container exec -it $CAR_NAME sh -c "exec psql -U postgres -h 172.17.0.3"

# 查看配置是否生效了
show max_connections;
show shared_buffers;
