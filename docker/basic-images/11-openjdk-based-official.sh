#!/bin/bash
set -e
BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

declare -A ArgDict
while getopts ":a:v:j:" arg_opt; do
    [ "$arg_opt" == "?" ] && die "Usage:  `basename $0` [-v 8/11 -j jre -a arm64v8]" "WARN"
    ArgDict["$arg_opt"]="$OPTARG"
    # echo "current arg : $arg_opt=$OPTARG"
done
# all cmd args
# echo "ArgDict=${!ArgDict[*]}"
ArchType="${ArgDict["a"]}"; ArchType=$(get_DockerArchName "${ArchType}"); ArchType_Prefix=${ArchType:+"${ArchType}/"}
Version="${ArgDict["v"]}"; Version=${Version:="11"}
JDK_OR_JRE="${ArgDict["j"]}"; [ "$JDK_OR_JRE" != "jre" ] && JDK_OR_JRE="jdk"
echo ; echo_info "Cmd args : ArchType=${ArchType}, Version=${Version}, JDK_OR_JRE=${JDK_OR_JRE}"

# FROM base image
FROM_IMAGE_NAME="${ArchType_Prefix}openjdk"
FROM_IMAGE_TAG="${Version}-${JDK_OR_JRE}-slim"
confirm_op "FROM base image => \033[33m${FROM_IMAGE_NAME}:${FROM_IMAGE_TAG}\033[0m"

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
IMAGE_NAME="${IMAGE_HEAD}${ArchType_Prefix}java-basic"
IMAGE_TAG="openjdk-${FROM_IMAGE_TAG}"

DFILE_NAME=/tmp/DF-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
# 为了避免国内对apt的缓存，最好使用https
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  TZ=Asia/Shanghai HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME

RUN  set -ex && \\
     sed -i 's#http://deb.debian.org#http://mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list && \\
     sed -i 's#http://security.debian.org#http://mirrors.tuna.tsinghua.edu.cn#g' /etc/apt/sources.list && \\
     apt-get update && \\
     ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone && \\
     apt-get install -yq --no-install-recommends locales procps nano openssh-server curl && \\
     localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \\
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
     mkdir /run/sshd && \\
     echo "root:hrs@6688" | chpasswd && \\
     echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \\
     echo "Done !"

WORKDIR /data

ENV  LANG=en_US.utf8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8

CMD  ["/usr/sbin/sshd", "-D"]
EOF
# -------------------------------- Dockerfile End  -------------------------------------
# --no-cache
docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
[ -f "$DOCKER_WORKDIR/.dockerignore" ] && rm -f $DOCKER_WORKDIR/.dockerignore || echo "file : $DOCKER_WORKDIR/.dockerignore not exist!"
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

echo_done
echo
exit 0
