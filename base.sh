#! /bin/bash

install_mac() {
  if (arch | grep -i -q "arm64"); then
    arch -arm64 brew install $1
  else
    brew install $1
  fi
}

install_linux() {
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

sed_text() {
  if (uname -s | grep -i -q "darwin"); then
    sed -i "" "$1" $2
  else
    sed -i "$1" $2
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
        install_mac $package
      else
        install_linux $package
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
    if !(command -v $package &> /dev/null); then
      if (uname -s | grep -i -q "darwin"); then
        brew remove $package
      else
        remove_linux $package
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
    sed_text "s/^$1.*/$1=$2/" ~/.kenote_profile
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
  system)
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
  esac
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
  get_info "${@:2}"
;;
*)
  get_env
;;
esac