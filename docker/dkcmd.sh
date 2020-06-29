#!/bin/bash

# BINDIR=$(cd $(dirname $0); pwd)
. /usr/local/bin/fd_utils.sh

function usage() {
    echo
    echo "Usage: `basename $0` [Options] [container name / image name]"
    echo "Options :"
    echo "  -m : 显示所有镜像"
    echo "  -a ：显示所有容器，否则只显示运行状态的容器"
    echo "  -g ：进入一个启动为服务的容器"
    echo "  -c ：创建一个临时容器并进入，退出时自动清理(--rm 方式)"
    echo "  -k ：清理掉容器（stop and rm）"
    echo "  -r ：重启容器"
    echo "  -D ：仅显示各种参数值。必须放在所有参数的最前面使用"
    echo 
    echo 
    if [ "Null$1" != "Null" ]; then
        echo_warn "$1"
        echo
    fi
    exit 1
}

# Is_killORrestart ： 说明输入了清理或重启容器的命令
# HAS_RUN_ARG : 说明输入了需要执行具体任务的命令，那么就不是列清单退出了
while getopts 'makrgc:D' arg_opt; do
  case ${arg_opt} in
    m) ARG_lsimage="ls" ;;
    a) ARG_lsall="-a" ;;
    g) ARG_goInto="true"
        HAS_RUN_ARG="true"
        ;;
    c) ARG_image="$OPTARG"
        HAS_RUN_ARG="true"
        ;;
    k) ARG_kill="true"
        Is_killORrestart="true"
        HAS_RUN_ARG="true"
        ;;
    r) ARG_restart="true"
        Is_killORrestart="true"
        HAS_RUN_ARG="true"
        ;;
    D) ARG_debug="true" ;;
    \?) usage ;;
  esac
done
# 获得剩余的命令行参数：也就是指定的容器名字（模糊匹配）
shift $((OPTIND-1))
CAR_NAME="$@"
# '-d'参数 ：仅显示各种参数值。必须放在所有参数的最前面使用
if [ "$ARG_debug" == "true" ]; then
    echo 
    echo "ARG_lsimage   : $ARG_lsimage"
    echo "ARG_lsall     : $ARG_lsall"
    echo "ARG_goInto    : $ARG_goInto"
    echo "ARG_image     : $ARG_image"
    echo "ARG_killv     : $ARG_kill"
    echo "ARG_restart   : $ARG_restart"
    echo "CAR_NAME      : $CAR_NAME"
    echo
    exit 1
fi
# 如果有 -m 参数，则只是为了显示镜像，忽略其他参数
if [ "$ARG_lsimage" == "ls" ]; then
    echo
    docker image ls --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    echo
    exit 0
fi

[ "${ARG_kill} AND ${ARG_restart}" == "true AND true" ] && usage "不能同时使用 -k 和 -r 参数！"

# ====>>>> 情况 1 ：'-c'参数 如果是要创建一个临时容器，那么优先处理这种情况
if [ "Null${ARG_image}" != "Null" ]; then
    # 检查该镜像是否存在
    img_nums=$(docker image ls | grep "$ARG_image" | wc -l)
    # if [ $img_nums -lt 1 ]; then
    #     die "image <$ARG_image> not exist !"
    if [ $img_nums -gt 1 ]; then
        docker image ls | grep -w "REPOSITORY"
        docker image ls | grep "$ARG_image"
        die "Too many images by '$ARG_image' !"
    fi
    echo
    echo ">>>> Create temp container by image <$ARG_image>"
    docker container run --rm -it ${ARG_image} /bin/bash
    exit 1
fi

# ====>>>> 情况 2 ：除了'-c'外的其他参数（都是和具体名字的容器相关的情况）
if [ "Null$CAR_NAME" == "Null" ]; then
    # 没有指定容器名，则列出所有并正常退出
    ls_container "ls $ARG_lsall"
    exit 0
elif [ "${HAS_RUN_ARG}" != "true" ]; then
    # 没有输入具体任务的命令，那么按照容器名使用 grep 进行过滤
    ls_container "ls $ARG_lsall" "$CAR_NAME"
    exit 0
fi

# 检查容器名是否会匹配到“多个存在的容器”，包括已经退出的容器
car_name_str=$(docker container ls -a --format "{{.Names}}" | grep "$CAR_NAME")
car_name_arr=($car_name_str)
car_name_num="${#car_name_arr[@]}"
if [ $car_name_num -lt 1 ]; then
    echo
    echo_error "Can not find container by '$CAR_NAME'"
    echo
    exit 2
elif [ $car_name_num -gt 1 ]; then
    echo
    echo_warn "Please choice one car name : "
    echo -e "\033[36m${car_name_str}\033[0m"
    echo
    exit 3
fi
# 得到确切的容器名字
CAR_NAME="$car_name_arr"

if [ "Null${ARG_kill}" != "Null" ]; then
    echo 
    echo_warn "Delete container : '$CAR_NAME'"
    echo
    echo -n "stop ... "
    docker container stop $CAR_NAME;
    echo -n "rm   ... "
    docker container rm   $CAR_NAME;
    echo
elif [ "Null${ARG_restart}" != "Null" ]; then
    echo 
    echo_warn "Restart container : '$CAR_NAME'"
    echo -n "restart ... "
    docker container restart $CAR_NAME
    echo
    echo
elif [ "Null${ARG_goInto}" != "Null" ]; then
    echo
    echo ">>>> Enter the container : $CAR_NAME"
    docker container exec -it $CAR_NAME /bin/bash
fi
