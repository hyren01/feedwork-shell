#!/bin/bash
# ============================================================
# 所有无gpu环境的python docker的基础镜像
# ============================================================
set -e
BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

declare -A ArgDict
while getopts ":v:a:t:" arg_opt; do
    [ "$arg_opt" == "?" ] && die "Usage:  `basename $0` [-t ubuntu-18.04 -v 3.6/3.7/2 -a arm64v8]" "WARN"
    ArgDict["$arg_opt"]="$OPTARG"
    # echo "current arg : $arg_opt=$OPTARG"
done
# all cmd args
# echo "ArgDict=${!ArgDict[*]}"
ArchType="${ArgDict["a"]}"; ArchType=$(get_DockerArchName "${ArchType}"); ArchType_Prefix=${ArchType:+"${ArchType}/"}
Version="${ArgDict["v"]:="3.6"}"
Arg_Tag="${ArgDict["t"]:="ubuntu-18.04"}"
echo ; echo_info "Cmd args : ArchType=${ArchType}, Version=${Version}, Tag=${Arg_Tag}"

# FROM base image
FROM_IMAGE_NAME="${IMAGE_HEAD}${ArchType_Prefix}os-basic"
FROM_IMAGE_TAG="${Arg_Tag}"
confirm_op "FROM base image => \033[33m${FROM_IMAGE_NAME}:${FROM_IMAGE_TAG}\033[0m"

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
IMAGE_NAME="${IMAGE_HEAD}python-basic"
IMAGE_TAG="${Version}-${FROM_IMAGE_TAG}"

DFILE_NAME=/tmp/DF-$IMAGE_TAG.df
# ----------------- Dockerfile Start -----------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME

RUN  set -ex && \\
     mkdir ~/.pip/ && \\
     apt-get update && \\
# python
     apt-get install -y --no-install-recommends python${Version} python3-dev python3-pip python3-setuptools && \\
     echo "[global]" > ~/.pip/pip.conf && \\
     echo "trusted-host = pypi.tuna.tsinghua.edu.cn" >> ~/.pip/pip.conf && \\
     echo "index-url = https://mirrors.aliyun.com/pypi/simple/" >> ~/.pip/pip.conf && \\
     python3 -m pip install --no-cache-dir -U setuptools pip && \\
     python3 -m pip install --no-cache-dir numpy==1.18.5 scipy pandas scikit-learn python-dateutil pyyaml && \\
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
# over
     echo "Done!"
EOF

# ----------------- Dockerfile End  -----------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
[ -f "$DOCKER_WORKDIR/.dockerignore" ] && rm -f $DOCKER_WORKDIR/.dockerignore || echo "file : $DOCKER_WORKDIR/.dockerignore not exist!"
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

echo_done
echo
exit 0
