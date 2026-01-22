#!/bin/bash

# basic vars
author=kelly-create
is_core=sing-box
is_core_name=sing-box
is_core_repo=SagerNet/$is_core
is_sh_repo=$author/$is_core

# paths
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_core
is_sh_dir=$is_core_dir/sh
is_config_json=$is_core_dir/config.json

# caddy paths
is_caddy_bin=/usr/local/bin/caddy
is_caddy_dir=/etc/caddy
is_caddy_repo=caddyserver/caddy
is_caddyfile=$is_caddy_dir/Caddyfile
is_caddy_conf=$is_caddy_dir/$author

# bash fonts colors
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_magenta() { echo -e ${magenta}$@${none}; }
_red_bg() { echo -e "\e[41m$@${none}"; }

_rm() {
    # safe rm: check if argument is provided and not root/empty
    [[ -z "$1" ]] && return
    [[ "$1" == "/" ]] && return
    rm -rf "$@"
}
_cp() { cp -rf "$@"; }
_sed() { sed -i "$@"; }
_mkdir() { mkdir -p "$@"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() {
    echo -e "\n$is_err $@\n"
    [[ $is_dont_auto_exit ]] && return
    exit 1
}

warn() {
    echo -e "\n$is_warn $@\n"
}

msg() {
    case $1 in
    warn) local color=$yellow ;;
    err) local color=$red ;;
    ok) local color=$green ;;
    *) echo -e "$@" && return ;;
    esac
    echo -e "${color}$(date +'%T')${none}) ${2}"
}

# wget with retry and timeout
_wget() {
    # [[ $proxy ]] && export https_proxy=$proxy
    # Check if wget supports -T (timeout) and -t (tries)
    # Busybox wget might not support logic, but standard wget does.
    # We assume standard environment or handle flags carefully if needed.
    # For now strict adding flags.
    wget --no-check-certificate -t 3 -T 10 "$@"
}

# compatibility check
cmd=$(type -P apt-get || type -P yum || type -P dnf || type -P pacman)

load() {
    . $is_sh_dir/src/$1
}

# auto install helper
check_install() {
    local pkg=$1
    if [[ ! $(type -P $pkg) ]]; then
        msg warn "缺少 $pkg, 尝试安装..."
        if [[ -z $cmd ]]; then
            msg err "未找到包管理器."
            return 1
        fi
        $cmd install -y $pkg &>/dev/null
        if [[ $? != 0 ]]; then
            $cmd update -y &>/dev/null
            $cmd install -y $pkg &>/dev/null
        fi
        if [[ ! $(type -P $pkg) ]]; then
            msg err "$pkg 安装失败."
        else
            msg ok "$pkg 安装成功."
        fi
    fi
}

# Get version and status
if [[ -f $is_core_bin ]]; then
    # sing-box version output: "sing-box version 1.8.0 ..."
    # we want just "1.8.0" (or similar)
    is_core_ver=$($is_core_bin version 2>/dev/null | head -n1 | awk '{print $3}')
    if systemctl is-active --quiet $is_core; then
        is_core_status=$(_green "运行中")
    else
        is_core_status=$(_red "未运行")
    fi
else
    is_core_ver=""
    is_core_status=$(_red "未安装")
fi
