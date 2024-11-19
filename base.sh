#! /bin/bash
KENOTE_BATH_TITLE=Bash脚本工具
KENOTE_BATH_VERSION=v1.0
KENOTE_PACK_MIRROR=https://mirrors.kenote.site/packages
KENOTE_SSH_PATH=$HOME/kenote_ssh
KENOTE_ACMECTL=$HOME/.acme.sh/acme.sh
KENOTE_SSL_PATH=/mnt/ssl
KENOTE_NGINX_HOME=/mnt/nginx-data
KENOTE_DOCKER_HOME=/mnt/docker-data

PKGTABS="subversion |svn|\nxfsprogs |xfs_growfs|\njava-1.8.0-openjdk |keytool|\nchrony |chronyd|\ninotify-tools |inotifywait|"

install_mac() {
  if (uname -a | grep -i -q "arm64"); then
    arch -arm64 brew install $1
  else
    brew install $1
  fi
}

install_linux() {
  if [[ $1 == 'yq' ]]; then
    if (uname -a | grep -i -q "arm64"); then
      wget $KENOTE_PACK_MIRROR/yq/yq_linux_arm64 -O /usr/bin/yq
    else
      wget $KENOTE_PACK_MIRROR/yq/yq_linux_amd64 -O /usr/bin/yq
    fi
    chmod +x /usr/bin/yq
    return
  fi
  if (command -v apt &> /dev/null); then
    apt update -y && apt install -y $1
  elif (command -v dnf &> /dev/null); then
    dnf install -y epel-release
    dnf update -y && dnf install -y $1
  elif (command -v yum &> /dev/null); then
    yum install -y epel-release
    yum update -y && yum install -y $1
  elif (command -v apk &> /dev/null); then
    apk update && apk add $1
  fi
}

remove_linux() {
  if [[ $1 == 'yq' ]]; then
    rm -rf /usr/bin/yq
    return
  fi
  if (command -v apt &> /dev/null); then
    apt remove -y $1
  elif (command -v dnf &> /dev/null); then
    dnf remove -y $1
  elif (command -v yum &> /dev/null); then
    yum remove -y $1
  elif (command -v apk &> /dev/null); then
    apk del $1
  fi
}

# 兼容macos sed -i 指令
sed_text() {
  if (uname -s | grep -i -q "darwin"); then
    sed -i "" "$1" $2
  else
    sed -i "$1" $2
  fi
}

# 获取软件包名称
get_pkgname() {
  if [[ -n $(echo -e "$PKGTABS" | grep -E "\|$1\|") ]]; then
    echo -e "$PKGTABS" | grep -E "\|$1\|" | awk -F " " '{print $1}'
  else
    echo "$1"
  fi
}

# 安装软件包
install() {
  if [ $# -eq 0 ]; then
    echo "未提供软件包参数!"
    return 1
  fi
  for package in "$@";
  do
    if !(command -v $package &> /dev/null); then
      if (uname -s | grep -i -q "darwin"); then
        install_mac "$(get_pkgname "$package")"
      else
        install_linux "$(get_pkgname "$package")"
      fi
    fi
  done
  return 0
}

# 删除软件包
remove() {
  if [ $# -eq 0 ]; then
    echo "未提供软件包参数!"
    return 1
  fi
  for package in "$@";
  do
    if (command -v $package &> /dev/null); then
      if (uname -s | grep -i -q "darwin"); then
        brew remove "$(get_pkgname "$package")"
      else
        remove_linux "$(get_pkgname "$package")"
      fi
    fi
  done
  return 0
}


# 获取全局变量
get_env() {
  if [[ ! -f ~/.kenote_profile ]]; then
    touch ~/.kenote_profile
  fi
  if [[ ! -n $1 ]]; then
    cat ~/.kenote_profile
    return
  fi
  value=$(sed -E '/^#.*|^ *$/d' ~/.kenote_profile | awk -F "^$1=" "/$1=/{print \$2}" | tail -n1)
  echo ${value[*]}
}

# 设置全局变量
set_env() {
  if [[ ! -f ~/.kenote_profile ]]; then
    touch ~/.kenote_profile
  fi
  if (cat ~/.kenote_profile | grep -q -E "^$1"); then
    sed_text "s/^$1.*/$1=$(echo "$2" | sed 's/\//\\\//g')/" ~/.kenote_profile
  else
    echo "$1=$2" >> ~/.kenote_profile
  fi
}

# 删除全局变量
del_env() {
  if [[ ! -f ~/.kenote_profile ]]; then
    touch ~/.kenote_profile
  fi
  for param in "$@";
  do
    sed_text "/^$param/d" ~/.kenote_profile
  done
}

# 获取文件路径
get_path() {
  if [[ -n $3 ]]; then
    HOME_ESCAPE=$(readlink -f $HOME/$3 | sed 's/\//\\\//g')
    echo "$1/$2" | sed "s/$HOME_ESCAPE\///"
  else
    echo "$1/$2"
  fi
}

# 获取信息
get_info() {
  case $1 in
  system | os)
    if (uname -s | grep -i -q "darwin"); then
      system_profiler SPSoftwareDataType | grep "System Version" | awk -F ": " '{print $2}'
    else
      cat /etc/os-release | grep "PRETTY_NAME" | sed 's/\(.*\)=\"\(.*\)\"/\2/g'
    fi
  ;;
  kernel)
    uname -sr
  ;;
  cpu)
    if (uname -s | grep -i -q "darwin"); then
      sysctl machdep.cpu | grep brand_string | awk -F ": " '{print $2}'
    else
      cat /proc/cpuinfo | grep "model name" | sed 's/\(.*\)\:\s\(.*\)/\2/g' | uniq
    fi
  ;;
  thread)
    if (uname -s | grep -i -q "darwin"); then
      sysctl machdep.cpu | grep thread_count | awk -F ": " '{print $2}'
    else
      cat /proc/cpuinfo | grep "physical id" | sort | uniq | wc -l
    fi
  ;;
  core)
    if (uname -s | grep -i -q "darwin"); then
      system_profiler SPHardwareDataType | grep "Total Number of Cores" | awk -F ": " '{print $2}'
    else
      cat /proc/cpuinfo | grep "processor" | sort | uniq | wc -l
    fi
  ;;
  speed)
    if (uname -s | grep -i -q "darwin"); then
      system_profiler SPHardwareDataType | grep "Processor Speed" | awk -F ": " '{print $2}'
    else
      awk -v x=$(cat /proc/cpuinfo | grep "cpu MHz" | sed 's/\(.*\)\:\s\(.*\)/\2/g' | uniq)  'BEGIN{printf "%.2f Mz", x}'
    fi
  ;;
  memory)
    if (uname -s | grep -i -q "darwin"); then
      system_profiler SPHardwareDataType | grep "Memory" | awk -F ": " '{print $2}'
    else
      free -b | awk 'NR==2{printf "%.f MB/%.f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}'
    fi
  ;;
  disk)
    if (uname -s | grep -i -q "darwin"); then
      diskutil list | grep "GUID_partition_scheme" | awk -F " " '{print $3" "$4}' | sed 's/^\*//'
    else
      fdisk -l | grep -E "(Disk|磁盘) /dev/(s|v)d" | sed -E 's/\:|：|,|，/ /g' | awk -F ' ' '{print $5}' | awk '{sum+=$1} END {print sum/1024/1024/1024, "GB"}'
    fi
  ;;
  ip)
    if (uname -s | grep -i -q "darwin"); then
      ifconfig | grep "inet " | awk -F " " '{print $2}' | grep -vE "\.1$" | tr '\n' ' ' && echo
    else
      ifconfig | grep "inet " | awk -F " " '{print $2}' | grep -vE "\.1$" | sed ':a;N;s/\n/ /g;ta'
    fi
  ;;
  date)
    if (uname -s | grep -i -q "darwin"); then
      date
    else
      timedatectl | grep "Local time" | sed -E 's/^(\s+)(Local\stime)\:\s//'
    fi
  ;;
  utc)
    if (uname -s | grep -i -q "darwin"); then
      date -u
    else
      timedatectl | grep "Universal time" | sed -E 's/^(\s+)(Universal\stime)\:\s//'
    fi
  ;;
  hostname)
    if (uname -s | grep -i -q "darwin"); then
      hostname
    else
      echo $(hostname) $(hostname -f)
    fi
  ;;
  ports)
    echo "TCP PORTS"
    echo "------------------------------------------"
    netstat -ntpl
    echo
    echo "UDP PORTS"
    echo "------------------------------------------"
    netstat -nupl
    echo
  ;;
  esac
}

# 设置源
set_mirror() {
  if [[ ! -n $1 ]]; then
    echo $KENOTE_BASH_MIRROR
    return
  fi
  if (uname -s | grep -i -q "darwin"); then
    sed_text "/^export KENOTE_BASH_MIRROR/d" ~/.zshrc
    echo "export KENOTE_BASH_MIRROR=$1" >> ~/.zshrc
  else
    sed_text "/^export KENOTE_BASH_MIRROR/d" ~/.bashrc
    echo "export KENOTE_BASH_MIRROR=$1" >> ~/.bashrc
  fi
}

# 设置热键
set_hotkey() {
  BASHFILE=~/.bashrc
  if (echo $SHELL | grep -q "zsh"); then
    BASHFILE=~/.zshrc
  fi
  if [[ ! -n $1 ]]; then
    echo "Hotkey = $(cat $BASHFILE | grep 'kenote/start.sh' | awk -F "=" '{print $1}' | awk -F " " '{print $2}')"
    return
  fi
  line=`cat $BASHFILE | grep -n "^alias" | awk -F ":" '{print $1}' | tail -n 1`
  if (cat $BASHFILE | grep -q "kenote/start.sh"); then
    sed -i "s/.*kenote\/start\.sh.*/alias $1='~\/kenote\/start\.sh'/" $BASHFILE
  else
    if [[ -n $line ]]; then
      sed -i "$((line+1)) i alias $1='~/kenote/start.sh'" $BASHFILE
    else
      echo -e "alias $1='~/kenote/start.sh'" >> $BASHFILE
    fi
  fi
}

# 初始化
init_sys() {
  if (uname -s | grep -i -q "darwin"); then
    env /usr/bin/arch -arm64 /bin/zsh ---login
    if !(command -v brew &> /dev/null); then
      install_brew
    fi
    install git svn python3 jq bc unzip wget htop yq
  else
    if (cat /etc/os-release | grep -q -E -i "debian"); then
      CODENAME=`cat /etc/os-release | grep "VERSION_CODENAME" | sed 's/\(.*\)=\(.*\)/\2/g'`
      if !(cat /etc/apt/sources.list | grep -q -E "^deb\shttp://deb.debian.org/debian"); then
        echo -e "deb http://deb.debian.org/debian ${CODENAME}-backports main contrib non-free" >> /etc/apt/sources.list
      fi
      if !(cat /etc/apt/sources.list | grep -q -E "^deb\-src\shttp://deb.debian.org/debian"); then
        echo -e "deb-src http://deb.debian.org/debian ${CODENAME}-backports main contrib non-free" >> /etc/apt/sources.list
      fi
    fi
    if !(command -v ifconfig &> /dev/null); then
      install net-tools
    fi
    install sudo git svn python3 jq bc tar unzip wget htop dpkg yq inotifywait
  fi
  mkdir -p ~/kenote
  if [[ ! -n $KENOTE_BASH_MIRROR ]]; then
    KENOTE_BASH_MIRROR=https://raw.githubusercontent.com/kenote/bash/main
  fi
  wget -O ~/kenote/core.sh $KENOTE_BASH_MIRROR/core.sh
  wget -O ~/kenote/start.sh $KENOTE_BASH_MIRROR/start.sh
  chmod +x ~/kenote/start.sh
  if [[ ! -f ~/.kenote_profile ]]; then
    touch ~/.kenote_profile
  fi
  set_env KENOTE_BATH_TITLE $KENOTE_BATH_TITLE
  set_env KENOTE_BATH_VERSION $KENOTE_BATH_VERSION
  if [[ ! -n $(get_env KENOTE_PACK_MIRROR) ]]; then
    set_env KENOTE_PACK_MIRROR $KENOTE_PACK_MIRROR
  fi
  set_env KENOTE_SSH_PATH $KENOTE_SSH_PATH
  set_env KENOTE_ACMECTL $KENOTE_ACMECTL
  set_env KENOTE_SSL_PATH $KENOTE_SSL_PATH
  set_env KENOTE_NGINX_HOME $KENOTE_NGINX_HOME
  set_env KENOTE_DOCKER_HOME $KENOTE_DOCKER_HOME
}

# 安装Homebrew
install_brew() {
  if (curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/[123].." &> /dev/null); then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    /bin/zsh -c "$(curl -fsSL https://gitee.com/cunkai/HomebrewCN/raw/master/Homebrew.sh)"
  fi
}

# 运行
case $1 in
--install)
  install "${@:2}"
;;
--remove)
  remove "${@:2}"
;;
--env)
  get_env "${@:2}"
;;
--set-env)
  set_env "${@:2}"
;;
--del-env)
  del_env "${@:2}"
;;
--get-path)
  get_path "${@:2}"
;;
--info)
  if [[ -n $2 ]]; then
    get_info "${@:2}"
  else
    echo "系统信息"
    echo "--------------------------------------------------"
    echo "发行版本: " $(get_info os)
    echo "内核版本: " $(get_info kernel)
    echo "硬件架构: " $(arch)
    echo "--------------------------------------------------"
    echo "CPU 型号: " $(get_info cpu)
    echo "CPU 个数: " $(get_info thread)
    echo "CPU 核心: " $(get_info core)
    if [[ -n $(get_info speed) ]]; then
      echo "CPU 频率: " $(get_info speed)
    fi
    echo "--------------------------------------------------"
    echo "内存大小: " $(get_info memory)
    if !(uname -s | grep -i -q "darwin"); then
      if [ $(free -b | awk 'NR==3{printf $2}') -gt 0 ]; then
        echo "虚拟内存: " $(free -b | awk 'NR==3{printf "%.f MB/%.f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')
      fi
    fi
    echo "磁盘大小: " $(get_info disk)
    echo "--------------------------------------------------"
    echo "主机名称: " $(get_info hostname)
    if !(uname -s | grep -i -q "darwin"); then
      echo "系统时区: " $(timedatectl | grep "Time zone" | sed -E 's/^(\s+)(Time\szone)\:\s//')
    fi
    echo "系统时间: " $(get_info date)
    echo "UTC 时间: " $(get_info utc)
    echo "--------------------------------------------------"
    if !(uname -s | grep -i -q "darwin"); then
      echo "运行时长: " $(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')
      echo "流量统计: " $(awk 'BEGIN { rx_total = 0; tx_total = 0 }
        NR > 2 { rx_total += $2; tx_total += $10 }
        END {
          rx_units = "Bytes";
          tx_units = "Bytes";
          if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
          if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
          if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

          if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
          if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
          if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

          printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
        }' /proc/net/dev)
      echo "--------------------------------------------------"
  
    fi
    echo "运 营 商: " $(curl -s https://ipinfo.io/org)
    echo "所在地区: " $(curl -s https://ipinfo.io/country)
    echo "所在城镇: " $(curl -s https://ipinfo.io/city)
    echo "--------------------------------------------------"
    echo "公 网 IP: " $(curl -s ipv4.ip.sb)
    echo "内 网 IP: " $(get_info ip)
    if [[ -n $(curl -s --max-time 2 ipv6.ip.sb) ]]; then
      echo "IPV6地址: " $(curl -s --max-time 2 ipv6.ip.sb)
    fi
    if (command -v getenforce &> /dev/null); then
      echo "SELINUX : " $(getenforce)
    fi
    echo
  fi
;;
--mirror)
  set_mirror "${@:2}"
;;
--init)
  case $2 in
  ssh)
    mkdir -p ~/kenote/ssh
    wget -O ~/kenote/ssh/init.sh $KENOTE_BASH_MIRROR/ssh/init.sh
    wget -O ~/kenote/ssh/server.sh $KENOTE_BASH_MIRROR/ssh/server.sh
    wget -O ~/kenote/ssh/task.sh $KENOTE_BASH_MIRROR/ssh/task.sh
    wget -O ~/kenote/ssh.sh $KENOTE_BASH_MIRROR/ssh.sh
    chmod +x ~/kenote/ssh.sh
  ;;
  disk)
    mkdir -p ~/kenote/disk
    wget -O ~/kenote/disk/base.sh $KENOTE_BASH_MIRROR/disk/base.sh
    wget -O ~/kenote/disk/swap.sh $KENOTE_BASH_MIRROR/disk/swap.sh
    wget -O ~/kenote/disk.sh $KENOTE_BASH_MIRROR/disk.sh
    chmod +x ~/kenote/disk.sh
  ;;
  cert)
    mkdir -p ~/kenote/cert
    wget -O ~/kenote/cert/acme.sh $KENOTE_BASH_MIRROR/cert/acme.sh
    wget -O ~/kenote/cert.sh $KENOTE_BASH_MIRROR/cert.sh
    chmod +x ~/kenote/cert.sh
  ;;
  nginx)
    mkdir -p ~/kenote/nginx
    wget -O ~/kenote/nginx/init.sh $KENOTE_BASH_MIRROR/nginx/init.sh
    if [[ ! -f ~/kenote/cert/acme.sh ]]; then
      mkdir -p ~/kenote/cert
      wget -O ~/kenote/cert/acme.sh $KENOTE_BASH_MIRROR/cert/acme.sh
    fi
    wget -O ~/kenote/nginx/server.sh $KENOTE_BASH_MIRROR/nginx/server.sh
    wget -O ~/kenote/nginx/proxy.sh $KENOTE_BASH_MIRROR/nginx/proxy.sh
    wget -O ~/kenote/nginx/upstream.sh $KENOTE_BASH_MIRROR/nginx/upstream.sh
    wget -O ~/kenote/nginx/stream.sh $KENOTE_BASH_MIRROR/nginx/stream.sh
    wget -O ~/kenote/nginx.sh $KENOTE_BASH_MIRROR/nginx.sh
    chmod +x ~/kenote/nginx.sh
  ;;
  sett)
    mkdir -p ~/kenote/system
    wget -O ~/kenote/system/base.sh $KENOTE_BASH_MIRROR/system/base.sh
    wget -O ~/kenote/sett.sh $KENOTE_BASH_MIRROR/sett.sh
    chmod +x ~/kenote/sett.sh
  ;;
  user)
    mkdir -p ~/kenote/system
    wget -O ~/kenote/system/user.sh $KENOTE_BASH_MIRROR/system/user.sh
    wget -O ~/kenote/user.sh $KENOTE_BASH_MIRROR/user.sh
    chmod +x ~/kenote/user.sh
  ;;
  cron)
    wget -O ~/kenote/cron.sh $KENOTE_BASH_MIRROR/cron.sh
    chmod +x ~/kenote/cron.sh
  ;;
  docker)
    mkdir -p ~/kenote/docker
    wget -O ~/kenote/docker/init.sh $KENOTE_BASH_MIRROR/docker/init.sh
    wget -O ~/kenote/docker/image.sh $KENOTE_BASH_MIRROR/docker/image.sh
    wget -O ~/kenote/docker/network.sh $KENOTE_BASH_MIRROR/docker/network.sh
    wget -O ~/kenote/docker/volume.sh $KENOTE_BASH_MIRROR/docker/volume.sh
    wget -O ~/kenote/docker/container.sh $KENOTE_BASH_MIRROR/docker/container.sh
    wget -O ~/kenote/docker/compose.sh $KENOTE_BASH_MIRROR/docker/compose.sh
    wget -O ~/kenote/docker.sh $KENOTE_BASH_MIRROR/docker.sh
    chmod +x ~/kenote/docker.sh
  ;;
  inbounds)
    wget -O $(get_env "KENOTE_NGINX_HOME")/inbound.sh $KENOTE_BASH_MIRROR/nginx/inbound.sh
    chmod +x $(get_env "KENOTE_NGINX_HOME")/inbound.sh
  ;;
  *)
    init_sys
  ;;
  esac
;;
--hotkey)
  set_hotkey "${@:2}"
;;
*)
  echo "KENOTE_BATH_TITLE=$KENOTE_BATH_TITLE"
  echo "KENOTE_BATH_VERSION=$KENOTE_BATH_VERSION"
  echo "KENOTE_BASH_MIRROR=$KENOTE_BASH_MIRROR"
  echo "KENOTE_PACK_MIRROR=$KENOTE_PACK_MIRROR"
  echo "KENOTE_SSH_PATH=$KENOTE_SSH_PATH"
  echo "KENOTE_ACMECTL=$KENOTE_ACMECTL"
  echo "KENOTE_SSL_PATH=$KENOTE_SSL_PATH"
  echo "KENOTE_NGINX_HOME=$KENOTE_NGINX_HOME"
  echo "KENOTE_DOCKER_HOME=$KENOTE_DOCKER_HOME"
;;
esac