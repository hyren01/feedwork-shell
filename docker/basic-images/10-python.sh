#!/bin/bash
# ============================================================
# 所有无gpu环境的python docker的基础镜像
# ============================================================
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
FROM_IMAGE_NAME="os-basic"
FROM_IMAGE_TAG="ubuntu-18.04$IMGTAG_DEV"

IMAGE_NAME="python-basic"
IMAGE_TAG="3.6$IMGTAG_DEV"

DFILE_NAME=/tmp/DF-$IMAGE_NAME-$IMAGE_TAG.df
# ----------------- Dockerfile Start -----------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME

RUN  set -ex && \\
     mkdir ~/.pip/ && \\
EOF

# 生产镜像会清理apt库，所以要加进来
if [ "$IMGTAG_DEV" != "-dev" ]; then
cat >>$DFILE_NAME <<EOF
     apt-get update && \\
EOF
fi

cat >>$DFILE_NAME <<EOF
     apt-get install -y --no-install-recommends python3.6 python3-dev python3-pip python3-setuptools && \\
     echo "[global]" > ~/.pip/pip.conf && \\
     echo "index-url = https://mirrors.aliyun.com/pypi/simple/" >> ~/.pip/pip.conf && \\
     pip3 install --upgrade setuptools pip && \\
     pip3 install --no-cache-dir numpy scipy pandas scikit-learn python-dateutil h5py pyyaml \\
EOF

# 生产镜像需要清理apt库
if [ "$IMGTAG_DEV" != "-dev" ]; then
cat >>$DFILE_NAME <<EOF
     && apt-get clean \\
     && rm -rf /var/lib/apt/lists/* \\
EOF
fi

cat >>$DFILE_NAME <<EOF
# over
     && echo "Done!"
EOF

# ----------------- Dockerfile End  -----------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
echo "" > $DOCKER_WORKDIR/.dockerignore;
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

exit 0
