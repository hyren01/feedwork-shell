#!/bin/bash
# common functions for all shell
# default location : /usr/local/bin

function echo_error() {
    echo 
    echo -e "\033[31m[ERROR]\033[0m $1"
    echo 
}

function echo_warn() {
    echo -e "\033[33m[WARNING]\033[0m $1"
}

function echo_info() {
    echo -e "[INFO ] $1"
}

function echo_tips() {
    if [ "$2" == "all" ]; then
        echo -e "\e[35m[TIPS ] $1\e[0m"
    else
        echo -e "\e[35m[TIPS ]\e[0m $1"
    fi
}

function echo_tips2() {
    if [ "$2" == "all" ]; then
        echo -e "\e[45m[TIPS ] $1\e[0m"
    else
        echo -e "\e[45m[TIPS ]\e[0m $1"
    fi
}

function echo_done() {
    local msg="$1"
    local msg=${msg:="Done !"}
    echo -e "\033[32m[SUCCESS]\033[0m $msg"
}

function die(){
    local msg="$1"
    if [ "Null$msg" == "Null" ]; then echo_error "Abort !"; exit 1; fi
    echo_error "$msg"
    exit 9
}

function confirm_op() {
    local msg="$1"
    if [ "Null$msg" == "Null" ]; then
        msg="Is everything OK ?"
    else
        msg="$msg  Is everything OK ?"
    fi
    echo
    echo_warn "$msg"
    read -p "[y/n] " inputKey
    if [ "$inputKey" != "y" ]; then echo ""; exit 1; fi
}

# 1: message for showing
# 2: var
# Usage: assert_nullvar "Missing username !" "$name"
function assert_nullvar() {
    local msg="$1"
    [ "Null$msg" == "Null" ] && die "Missing argument(msg) in assert_nullvar() !"
    local var_value="$2"
    if [ "x$var_value" == "x" ]; then
        die "$msg"
    fi
}

function assert_installed()
{
    local software_name="$1"
    [ "Null$software_name" == "Null" ] && die "Missing argument(software_name) in assert_installed() !"
    if hash $software_name 2>/dev/null; then
        return 0
    else
        die "<$software_name> is not exist !"
    fi
}

assert_ipaddr()
{
    local ipaddr="$1"
    local msg="$2"
    msg=${msg:="$ipaddr is not regular ip address !"}

    # IP address must be number
    echo "$ipaddr"|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" > /dev/null || die "$msg"
    # get ipaddr number split by "."
    local a=`echo $ipaddr|awk -F . '{print $1}'`
    local b=`echo $ipaddr|awk -F . '{print $2}'`
    local c=`echo $ipaddr|awk -F . '{print $3}'`
    local d=`echo $ipaddr|awk -F . '{print $4}'`
    for num in $a $b $c $d; do
        # must between 0-255
        if [ $num -gt 255 ] || [ $num -lt 0 ]; then
            die "$msg"
        fi
    done
}

# assert many files
# $1 : Multiple file names separated by spaces, OR '.' for all file
# $2 : exit OR warn
# $3 : file OR dir. default file if null
function assert_files() {
    local files="$1"
    [ "Null$files" == "Null" ] && die "Missing argument(files) in assert_files() !"
    local assert_do="$2"
    [ "Null$assert_do" == "Null" ] && die "Missing argument(assert_do) in assert_files() !"
    local ftype_name="$3"
    ftype_name=${ftype_name:="file"}
    local ftype="-f"
    [ "$ftype_name" == "dir" ] && ftype="-d"

    [ "$files" == "." ] && files=$(get_files "." "$ftype_name")
    # echo "will be assert files : $files"; echo "assert_do=$assert_do"; echo "ftype=$ftype";
    local file_arr=(${files})
    for filename in "${file_arr[@]}"; do
        # echo "cur filename=$filename"
        if [ ! $ftype "$filename" ]; then
            local tip=" -->> file <$filename> is not regular $ftype_name !"
            if [ "$assert_do" == "exit" ]; then
                die "$tip"
            else
                echo_warn "$tip"
            fi
        fi
    done
}

function mkdir_if_notexist()
{
    local new_dir="$1"
    [ "Null$new_dir" == "Null" ] && die "Missing argument(new dir) in mkdir_or_exit() !"
    local msg="$2"
    msg=${msg:="mkdir [$new_dir] failed !"}

    if [ ! -d "$new_dir" ]; then
        mkdir -p $new_dir || { die "$msg"; }
    fi
}

# $1 : src file
# $2 : dest dir OR file
# $3 : diff src and dest. value : 'diffAndCopy' OR 'diffOnly'
function file_cp_or_diff() {
    local src_file="$1"
    assert_nullvar "[src_file] must not null ! in cp_file()" "$src_file"
    local dest="$2"
    assert_nullvar "[dest] must not null ! in cp_file()" "$dest"
    local doType="$3"
    doType=${doType:="diffOnly"}

    FileSameMsg="[$src_file] is identical with dest:[$dest]."
    FileDiffMsg="\e[45m** Different **\e[0m [ $src_file ] with dest:[$dest]."
    if [ "$doType" == "diffAndCopy" ]; then
        # 文件相同，不需要做后续处理了
        if diff $src_file $dest > /dev/null 2>&1; then
            echo_info "$FileSameMsg -- Do not copy!"
            return 1
        else
            cp -f $src_file "$dest"
            if [ $? -ne 0 ]; then
                echo_error "cp -f [$src_file] to [${dest}] failed ! "
                return 2
            else
                echo_done "copy [ $src_file ] done."
                return 0
            fi
        fi
    else
        # 比较文件
        if [ ! -f "$dest" ]; then
            # 目的对象不是文件，不需要做比较，提示返回即可
            echo_warn "[$dest] is not regular file !"
            return 1
        fi
        if diff $src_file $dest > /dev/null 2>&1; then
            echo_info "$FileSameMsg"
            return 0
        else
            echo_warn "$FileDiffMsg"
            return 1
        fi
    fi
}

# $1 : search dir name
# $2 : search type. value : (file OR dir OR all), default 'file'
# $3 : include subdir or not. value : (all), default 'all'
# return : multiple filenames sperated by spaces
function get_files() {
    local root_dir="$1"
    [ "Null$root_dir" == "Null" ] && die "Missing argument(root_dir) in get_files() !"
    [ ! -d "$root_dir" ] && die "<$root_dir> is not regular dir !"
    root_dir=${root_dir%*/}
    local search_type="$2"
    if [ "Null$search_type" == "Null" ]; then
        search_type="-f"
    elif [ "$search_type" == "file" ]; then
        search_type="-f"
    elif [ "$search_type" == "dir" ]; then
        search_type="-d"
    elif [ "$search_type" == "all" ]; then
        search_type="all"
    else
        die "argument(search type) wrong value ! must be (file OR dir OR all)"
    fi
    local include_subdir="$3"

    file_arr=($(ls $root_dir))
    for filename in "${file_arr[@]}"; do
        echo "$filename" | grep " " >/dev/null 2>&1 && die "<$filename> name include spaces, Abort !"
        # echo "current filename : [$filename]"
        [ -L $filename ] && continue
        [ -h $filename ] && continue
        if [ "$search_type" == "all" ]; then
            all_files="$all_files $root_dir/$filename"
        elif [ $search_type $root_dir/$filename ]; then
            all_files="$all_files $root_dir/$filename"
        fi
    done
    all_files=${all_files/ /}
    echo "$all_files"
}

# ====================== below functions for docker ======================

# $1 : ls OR ls -a
# $2 : container name
function ls_container() {
    local arg_ls="$1"
    local arg_grep_carname="$2"
    arg_ls=${arg_ls:="ls"}
    echo 
    echo "============================================================="
    if [ "Null$arg_grep_carname" == "Null" ]; then
        echo_warn "Current container list :"
        docker container $arg_ls --format "table {{.ID}}  {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    else
        echo_warn "Current container list (by '$arg_grep_carname'):"
        docker container $arg_ls --format "table {{.ID}}  {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -w "NAMES"
        docker container $arg_ls --format "table {{.ID}}  {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep "$arg_grep_carname"
    fi
    echo 
}

# $1: IMAGE_NAME
# $2：IMAGE_TAG
# $3: showing tips if 'ShowTips'
function assert_mkimg() {
    local image_name="$1"
    [ "Null$image_name" == "Null" ] && die "Missing argument(image_name) in assert_mkimg() !"
    local image_tag="$2"
    [ "Null$image_tag" == "Null" ] && die "Missing argument(image_tag) in assert_mkimg() !"
    local image=$(docker image ls | grep "${image_name}" | grep "${image_tag}")
    if [ "Null$image" == "Null" ]; then
        die "create image <${image_name}:${image_tag}> failed !"
    fi
    if [ "$3" == "ShowTips" ]; then
        echo
        echo "========================================================================"
        echo "found image <${image_name}:${image_tag}>"
        echo 
        echo "you can try container:"
        echo "docker container run --rm -it ${image_name}:${image_tag} bash"
        echo 
    fi
}

# found only by ls -a 
function assert_diedcar() {
    local car_name="$1"
    [ "Null$car_name" == "Null" ] && die "Missing argument(car_name) in assert_diedcar() !"
    docker container ls -a | grep $car_name > /dev/null && die "You need clean dying container : $car_name"
}

# confirm docker logs
function confirm_carlog() {
    local car_name="$1"
    [ "Null$car_name" == "Null" ] && die "Missing argument(car_name) in confirm_carlog() !"

    local sleeps=1
    local log_text=$(docker logs --tail 5 $car_name)
    while true; do
        if [ "Null$log_text" == "Null" ]; then
            if [ $sleeps -gt 3 ]; then
                echo "."
                return 0
            fi
            echo -n ".."
            sleep 1
            sleeps=$(($sleeps + 1))
        else
            docker logs --tail 5 $car_name
            echo
            echo_warn "<$car_name> startup log as above, is everything OK?  ( Ctrl+c for exit )"
            read -p "[y/n] " inputKey
            if [ "$inputKey" == "y" ]; then return 0; fi
        fi
    done
}
