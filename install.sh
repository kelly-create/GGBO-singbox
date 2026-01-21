#!/bin/bash

# =========================================================
# Sing-box Installer
# Author: kelly-create
# =========================================================

# --- Bootstrap Logic ---
# Minimal definitions to get started
author=kelly-create
is_core=sing-box
is_core_dir=/etc/$is_core
is_sh_dir=$is_core_dir/sh
is_sh_repo=$author/$is_core

# Check Root
[[ $EUID != 0 ]] && echo -e "\nError: This script must be run as root!\n" && exit 1

# Check Systemd
if [[ ! $(type -P systemctl) ]]; then
    echo -e "\nError: systemd is required but not found.\n"
    exit 1
fi

# Check Architecture
case $(uname -m) in
amd64 | x86_64) is_arch=amd64 ;;
*aarch64* | *armv8*) is_arch=arm64 ;;
*) echo -e "\nError: Only 64-bit systems are supported.\n" && exit 1 ;;
esac

# Tmp Dir
tmpdir=$(mktemp -d) || tmpdir=/tmp/singbox_install_$RANDOM
mkdir -p $tmpdir

# --- Download & Init ---
echo -e "\nPreparing installation..."

# Function to download files (Bootstrap version)
_download_bootstrap() {
    local url=$1
    local dest=$2
    if command -v wget >/dev/null; then
        wget --no-check-certificate -q -c "$url" -O "$dest"
    elif command -v curl >/dev/null; then
        curl -sL "$url" -o "$dest"
    else
        echo "Error: neither wget nor curl is found."
        exit 1
    fi
}

# Variable to track file status
is_core_ok=$tmpdir/core.tar.gz
is_sh_ok=$tmpdir/sh.tar.gz
is_jq_ok=$tmpdir/jq

# Variables used in download function (compat with old structure)
tmpcore=$is_core_ok
tmpsh=$is_sh_ok
tmpjq=$is_jq_ok

# Parse Args (Minimal check for local install)
local_install=
for arg in "$@"; do
    if [[ "$arg" == "-l" || "$arg" == "--local-install" ]]; then
        local_install=1
        break
    fi
done

# Prepare Shell Scripts
if [[ $local_install ]]; then
    echo "Using local scripts..."
    # If local, we assume we are in the repo root
    if [[ -f "./src/init.sh" ]]; then
        mkdir -p $is_sh_dir
        cp -rf ./* $is_sh_dir/
    else
        echo "Error: Local install requested but ./src/init.sh not found."
        exit 1
    fi
else
    echo "Downloading scripts..."
    _download_bootstrap "https://github.com/${is_sh_repo}/archive/refs/heads/master.tar.gz" "$is_sh_ok"
    if [[ -f $is_sh_ok ]]; then
        mkdir -p $is_sh_dir
        tar zxf $is_sh_ok --strip-components 1 -C $is_sh_dir
    else
        echo "Error: Failed to download scripts."
        exit 1
    fi
fi

# Source init.sh
if [[ -f $is_sh_dir/src/init.sh ]]; then
    . $is_sh_dir/src/init.sh
else
    echo "Error: init.sh not found at $is_sh_dir/src/init.sh"
    exit 1
fi

# --- Main Logic (Using init.sh features) ---

# Variable adjustments to match init.sh if needed
# (Most are already in init.sh)

is_pkg="wget tar qrencode vim htop tree socat"
is_pkg_ok=$tmpdir/pkg_ok

# 兼容旧代码的变量名
jq_not_found=
if ! type -P jq >/dev/null; then jq_not_found=1; fi

# show help msg
show_help() {
    echo -e "Usage: $0 [-f xxx | -l | -p xxx | -v xxx | -h]"
    echo -e "  -f, --core-file <path>          自定义 $is_core_name 文件路径"
    echo -e "  -l, --local-install             本地获取安装脚本"
    echo -e "  -p, --proxy <addr>              使用代理下载"
    echo -e "  -v, --core-version <ver>        自定义 $is_core_name 版本"
    echo -e "  -h, --help                      显示此帮助界面\n"
    exit 0
}

# install dependent pkg
install_pkg() {
    cmd_not_found=
    for i in $*; do
        [[ ! $(type -P $i) ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        pkg=$(echo $cmd_not_found | sed 's/,/ /g')
        msg warn "安装依赖包 >${pkg}"
        
        # 使用 init.sh 中检测到的 cmd
        if [[ -z $cmd ]]; then
             msg err "无法检测到包管理器 (apt/yum/dnf/pacman)."
             exit 1
        fi
        
        $cmd install -y $pkg &>/dev/null
        if [[ $? != 0 ]]; then
            [[ $cmd =~ yum ]] && yum install epel-release -y &>/dev/null
            $cmd update -y &>/dev/null
            $cmd install -y $pkg &>/dev/null
            [[ $? == 0 ]] && >$is_pkg_ok
        else
            >$is_pkg_ok
        fi
    else
        >$is_pkg_ok
    fi
}

# download file
download() {
    case $1 in
    core)
        [[ ! $is_core_ver ]] && is_core_ver=$(_wget -qO- "https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM" | grep tag_name | egrep -o 'v([0-9.]+)')
        [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-${is_core_ver:1}-linux-${is_arch}.tar.gz"
        name=$is_core_name
        tmpfile=$is_core_ok
        ;;
    jq)
        link=https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_arch
        name="jq"
        tmpfile=$is_jq_ok
        ;;
    esac

    [[ $link ]] && {
        msg warn "下载 ${name} > ${link}"
        if _wget -c $link -O $tmpfile; then
            : # Success
        else
            msg err "下载 ${name} 失败!"
            return 1
        fi
    }
}

# get server ip
get_ip() {
    export "$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
    [[ -z $ip ]] && export "$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | grep ip=)" &>/dev/null
}

# parameters check
pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -f | --core-file)
            [[ -z $2 ]] && err "($1) 缺少参数"
            [[ ! -f $2 ]] && err "($2) 文件不存在"
            is_core_file=$2
            shift 2
            ;;
        -l | --local-install)
            local_install=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && err "($1) 缺少参数"
            proxy=$2
            export http_proxy=$proxy
            export https_proxy=$proxy
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && err "($1) 缺少参数"
            is_core_ver=v${2//v/}
            shift 2
            ;;
        -h | --help)
            show_help
            ;;
        *)
            # Err coming from init.sh
            msg err "Unknown argument: $1"
            show_help
            ;;
        esac
    done
}

# main
main() {
    # Check if installed
    if [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]]; then
         # Check if it's a reinstall or update request? 
         # Original logic just error out. 
         # But maybe we want to allow overwriting if -f is passed?
         # Keeping original logic for now but using msg err
         :
    fi

    [[ $# -gt 0 ]] && pass_args $@

    clear
    echo
    echo "........... $is_core_name script by $author .........."
    echo

    msg warn "开始安装..."
    [[ $is_core_ver ]] && msg warn "${is_core_name} 版本: ${yellow}$is_core_ver${none}"
    [[ $proxy ]] && msg warn "使用代理: ${yellow}$proxy${none}"
    
    # mkdir tmpdir (already done in bootstrap)
    
    # If is_core_file
    [[ $is_core_file ]] && {
        cp -f $is_core_file $is_core_ok
        msg warn "使用本地核心文件: $is_core_file"
    }

    # NTP check
    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && is_ntp_on=1

    # install dependent pkg
    install_pkg $is_pkg &
    PID_PKG=$!
    
    # jq
    if [[ $jq_not_found ]]; then
        download jq &
        PID_JQ=$!
    fi
     
    # download core
    if [[ ! $is_core_file ]]; then
        download core &
        PID_CORE=$!
    fi
    
    get_ip
    
    # Wait for all background jobs
    wait $PID_PKG
    [[ $PID_JQ ]] && wait $PID_JQ
    [[ $PID_CORE ]] && wait $PID_CORE
    
    # Check status
    if [[ ! -f $is_pkg_ok ]]; then
        msg err "依赖包安装失败."
    fi
    
    if [[ ! -f $is_core_ok ]]; then
        msg err "核心文件下载失败."
    fi
    
    if [[ $jq_not_found && ! -f $is_jq_ok ]]; then
        msg err "jq 下载失败."
    fi

    # Verify core file
    mkdir -p $tmpdir/testzip
    tar zxf $is_core_ok --strip-components 1 -C $tmpdir/testzip &>/dev/null
    if [[ $? != 0 || ! -f $tmpdir/testzip/$is_core ]]; then
        msg err "${is_core_name} 文件校验失败."
    fi

    # Get IP check
    if [[ ! $ip ]]; then
        msg err "无法获取服务器 IP."
    fi

    # --- Installation ---
    
    # sh dir already populated in bootstrap step
    
    # Create bin dir
    mkdir -p $is_core_dir/bin
    cp -rf $tmpdir/testzip/* $is_core_dir/bin/

    # Alias
    if ! grep -q "alias sb=" /root/.bashrc; then
        echo "alias sb=$is_sh_bin" >>/root/.bashrc
    fi
    if ! grep -q "alias $is_core=" /root/.bashrc; then
        echo "alias $is_core=$is_sh_bin" >>/root/.bashrc
    fi

    # Link logic
    ln -sf $is_sh_dir/$is_core.sh $is_sh_bin
    ln -sf $is_sh_dir/$is_core.sh ${is_sh_bin/$is_core/sb}

    # install jq
    [[ $jq_not_found ]] && mv -f $is_jq_ok /usr/bin/jq
    chmod +x /usr/bin/jq

    # chmod
    chmod +x $is_core_bin $is_sh_bin ${is_sh_bin/$is_core/sb}

    # logs
    mkdir -p $is_log_dir
    
    msg ok "生成配置文件..."

    # Systemd
    load systemd.sh
    is_new_install=1
    install_service $is_core &>/dev/null
    
    # Conf dir
    mkdir -p $is_conf_dir
    
    load core.sh
    
    # Reality config
    add reality
    
    # Cleanup
    _rm $tmpdir
    
    msg ok "安装完成!"
    
    # Enable and start service explicitly
    if systemctl is-enabled $is_core &>/dev/null; then
        msg warn "Starting $is_core service..."
        systemctl restart $is_core
        sleep 2
        if systemctl is-active --quiet $is_core; then
            msg ok "$is_core is running."
        else
             msg err "$is_core failed to start. Check logs: journalctl -u $is_core"
        fi
    else
        msg err "Service not enabled."
    fi
}

main $@
