#!/bin/bash

[ -f /usr/local/bin/fd_utils.sh ] || exit 99
. /usr/local/bin/fd_utils.sh

BINDIR=$(cd `dirname $0`; pwd)
BUILD_TIME=$(date "+%Y%m%d-%H%M%S")
echo "Current dir  : $BINDIR"
echo "Current time : $BUILD_TIME"

if [ -f env-docker.sh ]; then
    . env-docker.sh
fi

