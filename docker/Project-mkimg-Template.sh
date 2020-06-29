#!/bin/bash

set -e
. func_docker.sh

# ========== 命令行参数处理 ==========
function usage() {
    echo
    echo "Usage:  `basename $0` [Options]"
    echo "Options :"
    echo "    -d <resource dir>   : 构建镜像时的工作目录，也就是ADD/COPY使用的根目录"
    echo "    -s <subsys name>    : 子系统名"
    echo "    -t <subsys version> : 子系统版本。可空，默认为 1.0"
    echo "    -W <car workdir>    : 容器的WORKDIR。可空，默认为 /opt/hrapp"
    echo "    -D <show parameter> : 仅显示各种参数值。"
    echo
    if [ "Null$1" != "Null" ]; then
    echo_warn "$1"
    echo
    fi
    exit 1
}

while getopts ':d:s:t:W:D' arg_opt; do
  case ${arg_opt} in
    d) IMAGE_RESDIR="$OPTARG"       ;;
    s) SUBSYS_NAME="$OPTARG"         ;;
    t) SUBSYS_VER="$OPTARG"          ;;
    W) CONTAINER_WORKDIR="$OPTARG"  ;;
    D) ARG_debug="true" ;;
    \?) usage ;;
  esac
done
# 获得剩余的命令行参数
shift $((OPTIND-1))
OTHER_VALUES="$@"
# 回显命令行参数值
if [ "$ARG_debug" == "true" ]; then
    echo
    echo "============================================="
    echo_info "resource dir  : $IMAGE_RESDIR"
    echo_info "subsys name   : $SUBSYS_NAME"
    echo_info "subsys ver    : $SUBSYS_VER"
    echo_info "car workdir   : $CONTAINER_WORKDIR"
    echo "============================================="
    echo
    exit 1
fi
echo 
# 参数检查
[ -d "$IMAGE_RESDIR" ] || usage "image resource dir <$IMAGE_RESDIR> is not regular dir !"
[ "Null$SUBSYS_NAME" == "Null" ] && usage "Missing <subsys name>"
SUBSYS_VER=${SUBSYS_VER:="1.0"}
CONTAINER_WORKDIR=${CONTAINER_WORKDIR:="/opt/hrapp"}


# ========== 设置构建镜像时的资源环境 ==========
# '*' ~ '.git'之间，填写所有需要构建进镜像的目录和文件，以半角感叹号起头。
# 文件以.git结尾是为了防止中间配置的目录中包含了.git
# 例如：
# !start-app.sh
# !service/resources
cat > $IMAGE_RESDIR/.dockerignore << EOF
*

.git/
.git*
EOF

FROM_IMAGE_NAME="java-basic"
FROM_IMAGE_TAG="openjdk-8-jre-slim"

IMAGE_NAME="hrs-$SUBSYS_NAME"
IMAGE_TAG="$SUBSYS_VER"

# ========== 创建 Dockerfile ==========
# 1. 把需要写入镜像的文件/目录，拷贝到资源环境中
# CONTAINER_START_SH="start-app.sh"
# cp -rf $START_SH $IMAGE_RESDIR

# 2. 设置Dockerfile里面需要的各种变量
DBINFO_CONF="${CONTAINER_WORKDIR}/service/resources/fdconfig/dbinfo.conf"
Httpserver_conf="${CONTAINER_WORKDIR}/service/resources/fdconfig/httpserver.conf"

# 3. 编写Dockerfile。注意：正确使用反斜线！
#  * 必须设置环境变量：HRS_BUILD_TIME=$BUILD_TIME
#  * 非必要软件，不要安装。如果一定需要编辑器，安装nano（不要装vi）
#  * 基础镜像不允许使用网上自己下载的！
DFILE_NAME=/tmp/DF-$IMAGE_NAME-$IMAGE_TAG.df
cat > $DFILE_NAME << EOF
FROM swr.cn-east-2.myhuaweicloud.com/hrs/$FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME

ADD  . $CONTAINER_WORKDIR

RUN  set -ex && \\
     sed -i "s#jdbc:postgresql://.*#jdbc:postgresql://$CAR_HRSDB_IP:5432/postgres#" $DBINFO_CONF && \\
     sed -i "s#username[[:space:]]*:.*#username  : postgres#g" $DBINFO_CONF && \\
     sed -i "s#password[[:space:]]*:.*#password  : 123456#g" $DBINFO_CONF && \\
     sed -i "s#[[:space:]]*host[[:space:]]*:.*##g" $Httpserver_conf && \\
     echo "Done!"

WORKDIR $CONTAINER_WORKDIR

EXPOSE 8888

CMD ["bash", "$CONTAINER_START_SH"]

EOF
# echo "=====>>>>> debug exit : $DFILE_NAME"; exit 1

sleep 1

# ========== 构建镜像 ==========
docker build --no-cache -f $DFILE_NAME -t ${IMAGE_NAME}:${IMAGE_TAG} $IMAGE_RESDIR
assert_mkimg "${IMAGE_NAME}" "${IMAGE_TAG}" "ShowTips"

# ========== 构建镜像完成，正常退出 ==========
exit 0


# ==============================================================
# ！！！！！ 以下代码不执行！！！！！ 
# 这里往下，写上使用本镜像启动容器的样例命令，用于测试该镜像是否可以使用。
# ==============================================================

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
