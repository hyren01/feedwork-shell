#!/bin/bash

BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

#JDK_OR_JRE="$1"
#if [[ "$JDK_OR_JRE" != "jdk" ]] && [[ "$JDK_OR_JRE" != "jre" ]]; then
#    die "first argument must be 'jdk' or 'jre' !"
#fi

# 如果要构建的OS基础镜像是为了开发使用，那么命令行传入 '-dev'。这种镜像会有ssh, vim等软件
IMGTAG_DEV="$1"
[ "$IMGTAG_DEV" != "-dev" ] && IMGTAG_DEV=""

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
PACKAGESRV_IP="172.168.0.100"
WEBPATH="/yum/package/java/"

FROM_IMAGE_NAME="os-basic"
FROM_IMAGE_TAG="centos-7.6"

IMAGE_NAME="java-basic"
IMAGE_TAG="oraclejdk-centos$IMGTAG_DEV"

DFILE_NAME=/tmp/DF-$IMAGE_NAME-$IMAGE_TAG.df
# -------------------------------- Dockerfile Start --------------------------------------
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai

RUN  set -ex \\
     && yum install -y wget \\
     && ln -snf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone \\
     && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \\
     && mkdir /opt/java/ \\
     && cd /tmp \\
     && wget -r -np -nH -R index.htm http://${PACKAGESRV_IP}${WEBPATH} \\
     && cd /tmp${WEBPATH} \\
     && tar -zxf jdk-8u181-linux-x64.tar.gz \\
     && mv jdk1.8.0_181/ /opt/java/ \\
     && rm -rf /tmp/${WEBPATH} \\
EOF
if [ "$IMGTAG_DEV" == "-dev" ]; then
cat >>$DFILE_NAME <<EOF
# ssh, gcc, vi, git, and so on. only for dev stage!
     && yum install -y openssh-server gcc net-tools vim wget bzip2 unzip curl git \\
     && mkdir /run/sshd \\
     && echo "root:hrs@6688" | chpasswd \\
     && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \\
     && ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key \\
     && ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key \\
     && ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key \\
EOF
else
# 生产模式，清理各种缓存文件
cat >>$DFILE_NAME <<EOF
       && yum clean all \\
    #  && apt-get clean \\
    #  && rm -rf /var/lib/apt/lists/* \\
EOF
fi
cat >>$DFILE_NAME <<EOF
# over
     && echo "Done!"
     
WORKDIR /data

ENV LANG=en_US.utf8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8 JAVA_HOME="/opt/java/jdk1.8.0_181" JRE_HOME="\${JAVA_HOME}/jre"
ENV PATH="\$PATH:\$JRE_HOME/bin:\$JAVA_HOME/bin"

EOF
# -------------------------------- Dockerfile End  -------------------------------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
echo "" > $DOCKER_WORKDIR/.dockerignore;
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

exit 0
