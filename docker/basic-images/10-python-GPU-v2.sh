#!/bin/bash
# ============================================================
# 所有gpu环境的python docker的基础镜像
# ============================================================
set -e
BINDIR=$(cd `dirname $0`; pwd)
. $BINDIR/env-for-basic-img.sh

declare -A ArgDict
while getopts ":v:" arg_opt; do
    [ "$arg_opt" == "?" ] && die "Usage:  `basename $0` [-v 3.6.9/3.7.8/3.8.4]" "WARN"
    ArgDict["$arg_opt"]="$OPTARG"
    # echo "current arg : $arg_opt=$OPTARG"
done
# all cmd args
# echo "ArgDict=${!ArgDict[*]}"
ArchType=""; ArchType=$(get_DockerArchName "${ArchType}"); ArchType_Prefix=${ArchType:+"${ArchType}/"}
Version="${ArgDict["v"]}"; Version=${Version:="3.6"}
echo ; echo_info "Cmd args : ArchType=${ArchType}, Version=${Version}"

# FROM base image
FROM_IMAGE_NAME="nvidia/cuda"
FROM_IMAGE_TAG="10.0-cudnn7-runtime-ubuntu18.04"
confirm_op "FROM base image => \033[33m${FROM_IMAGE_NAME}:${FROM_IMAGE_TAG}\033[0m"

DOCKER_WORKDIR="."
# 【设置 .dockerignore】
cat > $DOCKER_WORKDIR/.dockerignore << EOF
*
EOF

# 【构建镜像】
IMAGE_NAME="${IMAGE_HEAD}python-basic"
IMAGE_TAG="${Version}-GPU-cuda10.0"

DFILE_NAME=/tmp/DF-$IMAGE_TAG.df
# ----------------- Dockerfile Start -----------------
PYTHON_VERSION=${Version}
cat >$DFILE_NAME <<EOF
FROM $FROM_IMAGE_NAME:$FROM_IMAGE_TAG

ENV  HR_OSLABEL=$IMAGE_NAME:$IMAGE_TAG HRS_BUILD_TIME=$BUILD_TIME \\
     TZ=Asia/Shanghai DEBIAN_FRONTEND=noninteractive

RUN  set -ex && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse" > /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-proposed main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-proposed main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list && \\
     echo "deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse" >> /etc/apt/sources.list && \\
     apt-get update && \\
# tzdata locales
     apt-get install -y --no-install-recommends tzdata && \\
     ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone && \\
     dpkg-reconfigure -f noninteractive tzdata && \\
     apt-get install -yq --no-install-recommends locales && \\
     localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \\
# ssh, gcc, vi, git, and so on. only for dev stage!
     apt-get install -yq --no-install-recommends openssh-server gcc net-tools nano unzip curl wget && \\
     mkdir /run/sshd && \\
     echo "root:hrs@6688" | chpasswd && \\
     echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \\
     echo "System soft Done!"

# python TODO: 这种方式安装3.7后，再安装pip时，因为缺少distutils.util而需要装python3-distutils，但这会导致系统被装成了3.6.9
ENV PATH /usr/local/bin:$PATH
RUN  set -ex && \\
     wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" && \\
     apt install -y --no-install-recommends \\
        autoconf automake bzip2 dpkg-dev file g++ gcc imagemagick libbz2-dev libc6-dev \\
        libcurl4-openssl-dev libdb-dev libevent-dev libffi-dev libgdbm-dev libglib2.0-dev libgmp-dev \\
        libjpeg-dev libkrb5-dev liblzma-dev libmagickcore-dev libmagickwand-dev libmaxminddb-dev \\
        libncurses5-dev libncursesw5-dev libpng-dev libpq-dev libreadline-dev libsqlite3-dev \\
        libssl-dev libtool libwebp-dev libxml2-dev libxslt-dev libyaml-dev \\
        make patch unzip xz-utils zlib1g-dev tk-dev uuid-dev && \\
     mkdir -p /usr/src/python && \\
     tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz && \\
     rm python.tar.xz && cd /usr/src/python && \\
     ./configure --enable-loadable-sqlite-extensions --enable-optimizations --enable-option-checking=fatal \\
        --enable-shared --with-system-expat --with-system-ffi && \\
     make -j "$(nproc)" PROFILE_TASK='-m test.regrtest --pgo \\
        test_array test_base64 test_binascii test_binhex test_binop test_bytes test_class \\
        test_c_locale_coercion test_cmath test_codecs test_compile test_complex test_csv \\
        test_decimal test_dict test_float test_fstring test_hashlib test_io test_iter \\
        test_json test_long test_math test_memoryview test_pickle test_re test_set test_slice \\
        test_struct test_threading test_time test_traceback test_unicode' && \\
     make install && \\
     ldconfig && \\
     find /usr/local -depth \\
        \\( \\
            \\( -type d -a \\( -name test -o -name tests -o -name idle_test \\) \\) \\
            -o \\
            \\( -type f -a \\( -name '*.pyc' -o -name '*.pyo' \\) \\) \\
        \\) -exec rm -rf '{}' + && \\
     rm -rf /usr/src/python && \\
     python3 --version && \\
     cd /usr/local/bin && \\
     ln -s idle3 idle && \\
     ln -s pydoc3 pydoc && \\
     ln -s python3 python && \\
     ln -s python3-config python-config && \\

     mkdir ~/.pip/ && \\
     echo "[global]" > ~/.pip/pip.conf && \\
     echo "trusted-host = pypi.tuna.tsinghua.edu.cn" >> ~/.pip/pip.conf && \\
     echo "index-url = https://pypi.tuna.tsinghua.edu.cn/simple/" >> ~/.pip/pip.conf && \\
# clean
     apt-get clean && \\
     rm -rf /var/lib/apt/lists/* && \\
# over
     echo "Done!"

WORKDIR /data

ENV LANG=en_US.utf8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8

CMD  ["/usr/sbin/sshd", "-D"]
EOF
# ----------------- Dockerfile End  -----------------

docker build -f $DFILE_NAME -t $IMAGE_NAME:$IMAGE_TAG $DOCKER_WORKDIR
[ -f "$DOCKER_WORKDIR/.dockerignore" ] && rm -f $DOCKER_WORKDIR/.dockerignore || echo "file : $DOCKER_WORKDIR/.dockerignore not exist!"
assert_mkimg $IMAGE_NAME $IMAGE_TAG "ShowTips"

echo_done
echo
exit 0
