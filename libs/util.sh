#!/bin/bash
# 依赖库
# 1. 输出颜色定义
# 2. 下载封装
# 3. 系统相关工具

# shellcheck disable=SC2034
C_NONE="\033[0m"
# Regular
C_BLACK="\033[0;30m"
C_RED="\033[0;31m"
C_GREEN="\033[0;32m"
C_YELLOW="\033[0;33m"
C_BLUE="\033[0;34m"
C_PURPLE="\033[0;35m"
C_CYAN="\033[0;36m"
C_WHITE="\033[0;37m"
#Bold
C_BBLACK="\033[1;30m"
C_BRED="\033[1;31m"
C_BGREEN="\033[1;32m"
C_BYELLOW="\033[1;33m"
C_BBLUE="\033[1;34m"
C_BPURPLE="\033[1;35m"
C_BCYAN="\033[1;36m"
C_BWHITE="\033[1;37m"
# High Intensity
C_IBLACK="\033[0;90m"
C_IRED="\033[0;91m"
C_IGREEN="\033[0;92m"
C_IYELLOW="\033[0;93m"
C_IBLUE="\033[0;94m"
C_IPURPLE="\033[0;95m"
C_ICYAN="\033[0;96m"
C_IWHITE="\033[0;97m"
# Bold High Intensity
C_BIBLACK="\033[1;90m"
C_BIRED="\033[1;91m"
C_BIGREEN="\033[1;92m"
C_BIYELLOW="\033[1;93m"
C_BIBLUE="\033[1;94m"
C_BIPURPLE="\033[1;95m"
C_BICYAN="\033[1;96m"
C_BIWHITE="\033[1;97m"


is_success(){
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

prepare_source_by_wget(){
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "usage: prepare_source_by_wget <file-name> <download-url>"
        exit 1
    fi

    local file=$1
    local url=$2

    if [ ! -f "$file" ]; then
        wget --quiet --show-progress "${url}" -O "${file}"
    fi

    basename=$(basename -- "$file")
    local filename="${basename}"
    local extension="${filename##*.}"

    if [ "$extension" == "bz2" ]; then
        echo "tar xjf $file"
        pv "${file}" | tar xjf -
    elif [ "$extension" == "zip" ]; then
        echo "unzip -q $file"
        unzip -q "${file}"
    elif [ "$extension" == "gz" ]; then
        echo "tar xzf $file"
        pv "${file}" | tar xzf -
    else
        echo "do nothing for '.$extension' file!"
    fi

    is_success
}

prepare_source_by_git(){
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "usage: prepare_source_by_git <git-rep-name> <directory-name>"
        exit 1
    fi

    local rep=$1
    local directory=$2

    if [ -d "$directory" ]; then
        rm -rf "${directory}"
    fi

    git clone --recurse-submodules "${rep}" "${directory}"

    is_success
}

force_cd(){
    if [ -z "$1" ]; then
        echo "usage: enter_path <path>"
    fi

    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
    cd "$1" || exit
}

get_inet_ip_decimal(){
    a=$( ip address | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' )
    local ip="${a}"
    IFS=.
    read -r a b c d <<< "$ip"
    echo "$((a * 16777216 + b * 65536 + c * 256 + d))"
}

is_centos_version(){
    if [ -f /etc/redhat-release ]; then
        local code=$1
        osVersion=$(get_os_version)
        local version="${osVersion}"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

check_gcc_version(){
    if [ -z "$1" ]; then
        echo "usage: check_gcc_version <minimum version>"
        exit 1
    fi

    GCC_VERSION="$(gcc -dumpversion)"
    GCC_REQUIRED=$1
    if [ "$(printf '%s\n' "$GCC_REQUIRED" "$GCC_VERSION" | sort -V | head -n1)" = "$GCC_REQUIRED" ]; then
        echo "true"
    else
        echo "false"
    fi

}

get_os_version() {
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

join() { 
    local IFS="$1"; 
    shift; 
    echo "$*"; 
}

exists_command()
{
  command -v "$1" >/dev/null 2>&1
}