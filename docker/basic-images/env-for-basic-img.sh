
if [ ! -f /usr/local/bin/fd_utils.sh ]; then
    echo "[Fatal Error] Missing hrs utils !"
    exit 99
fi
. /usr/local/bin/fd_utils.sh

BUILD_TIME=$(date "+%Y%m%d")
IMAGE_HEAD="hrs/"
