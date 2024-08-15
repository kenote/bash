#! /bin/bash
CURRENT_DIR=$(cd $(dirname $0);pwd)
if [[ ! -n $KENOTE_BASH_MIRROR ]]; then
  KENOTE_BASH_MIRROR=https://raw.githubusercontent.com/kenote/bash/main
fi
KENOTE_BATH_TITLE=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_BATH_TITLE)
KENOTE_BATH_VERSION=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_BATH_VERSION)
KENOTE_PACK_MIRROR=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_PACK_MIRROR)
KENOTE_SSH_PATH=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_SSH_PATH)
KENOTE_ACMECTL=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_ACMECTL)
KENOTE_SSL_PATH=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_SSL_PATH)
KENOTE_NGINX_HOME=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_NGINX_HOME)
KENOTE_DOCKER_HOME=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_DOCKER_HOME)

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 兼容macos sed -i 指令
sed_text() {
  if (uname -s | grep -i -q "darwin"); then
    sed -i "" "$1" $2
  else
    sed -i "$1" $2
  fi
}

# 解析路径
parse_path() {
  if [[ -n $(echo $1 | gawk '/^([a-zA-Z0-9\.\-_])/{print 0}') ]]; then
    echo "$CURRENT_DIR/$1"
  else
    eval echo "$1"
  fi
}

# 运行脚本
run_script() {
  filepath=`curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --get-path $CURRENT_DIR $1`
  urlpath=`curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --get-path $CURRENT_DIR $1 "kenote"`
  if [[ ! -f $filepath ]]; then
    mkdir -p $(dirname $filepath)
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --init $(echo $urlpath | sed 's/\.sh$//')
    clear
  fi
  bash $filepath "${@:2}"
}

# 快捷键返回
goback() {
  # 按 #1 返回
  if [[ -n $(echo $1 | grep -iE "^\#1$") ]]; then
    eval "$2"
    exit
  # 按 #2 刷新
  elif [[ -n $(echo $1 | grep -iE "^\#2$") ]]; then
    eval "$3"
    exit
  # 按 #0 退出
  elif [[ -n $(echo $1 | grep -iE "^\#0$") ]]; then
    clear
    exit 0
  fi
}

# 警告提示
warning() {
  if [[ -n $2 || -n $3 ]]; then
    clear
    if [[ -n $2 ]]; then
      echo -e $2
    fi
    if [[ -n $3 ]]; then
      if [[ -n $2 ]]; then
        echo
      fi
      eval "$3"
      echo
    fi
  fi
  echo -e "${red}$1${plain}"
  echo
}

# 获取子栏目头信息
get_sub_note() {
  echo $1
  echo "------------------------"
  if [[ -n $2 ]]; then
    echo
    eval "$2"
    echo
  fi
}

# 确认对话
confirm() {
  if [[ $# > 1 ]]; then
    echo && read -p "$1 [默认$2]: " temp
    if [[ x"${temp}" == x"" ]]; then
      temp=$2
    fi
  else
    read -p "$1 [y/n]: " temp
  fi
  if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
    return 0
  else
    return 1
  fi
}

# 选择可选值
switch_value() {
  if [[ -n $2 ]]; then
    clear
    echo -e $2
  fi
  i=0
  for name in $(echo $1)
  do
    echo "$((i+1)). $name"
    i=$((i+1))
  done
  unset name i
  echo
  read -p "请输入选择: " value
  goback $value "$3"
  if [[ ! -n $value && -n $(echo $1 | awk -F " " "{print \$$value}") ]]; then
    switch_value "$1" "$2" "$3"
  fi
}

# 显示标题
show_title() {
  echo -e "${green}_  _ ____ _  _ ____ ___ ____  "
  echo "|_/  |___ |\ | |  |  |  |___  "
  echo "| \_ |___ | \| |__|  |  |___  "
  echo -e "${plain}"
  echo "$KENOTE_BATH_TITLE $KENOTE_BATH_VERSION"
}

# 测试包
test_package() {
  if (command -v apt &> /dev/null); then
    apt info $1 | grep -q -iE "Version|版本"
  elif (command -v dnf &> /dev/null); then
    dnf info $1 | grep -q -iE "Version|版本"
  elif (command -v yum &> /dev/null); then
    yum info $1 | grep -q -iE "Version|版本"
  elif (command -v apk &> /dev/null); then
    apk info $1 | grep -q -iE "Version|版本"
  fi
}

# 安装 btop
install_btop() {
  if (test_package btop); then
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install btop
  else
    if (curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/[123].." &> /dev/null); then
      BTOP_VERSION=`curl -s https://api.github.com/repos/aristocratos/btop/releases/latest | jq -r ".tag_name"`
      wget --no-check-certificate https://github.com/aristocratos/btop/releases/download/${BTOP_VERSION}/btop-$(arch)-linux-musl.tbz
    else
      wget --no-check-certificate $KENOTE_PACK_MIRROR/btop/btop-$(arch)-linux-musl.tbz
    fi
    if !(command -v bunzip2 &> /dev/null); then
      curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install bzip2
    fi
    bunzip2 btop-$(arch)-linux-musl.tbz
    tar xvf btop-$(arch)-linux-musl.tar
    cd btop
    make install PREFIX=/usr/local/btop
    ln -s /usr/local/btop/bin/btop /usr/bin/btop
  fi
}

# 判断IP地址合法性
is_ipadress() {
  echo "$1" | gawk '/^((2(5[0-5]|[0-4][0-9]))|[0-1]?[0-9]{1,2})(\.((2(5[0-5]|[0-4][0-9]))|[0-1]?[0-9]{1,2})){3}$/{print $0}'
}

# 判断域名合法性
is_domain() {
  echo "$1" | gawk '/^[a-zA-Z0-9\*][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+$/{print $0}'
}

# 判断URL
is_url() {
  echo "$1" | gawk '/^(http|https):\/\/[^/s]*/{print $0}'
}

# 判断多个参数
is_param_true() {
  list=($2)
  for _name in "${list[@]}"
  do
    if [[ ! -n $(eval "$1" "$_name") ]]; then
      return 1
    fi
  done
}

# 转换数组参数
to_array_param() {
  list=($2)
  param=""
  for name in "${list[@]}"
  do
    param="$param $1 $name"
  done
  echo $param
}

# 判断端口
is_port() {
  echo "$1" | gawk '/^[1-9]{1}[0-9]{1,5}$/{print $0}'
}

# 判断电子邮箱
is_email() {
  echo "$1" | gawk '/^([a-zA-Z0-9_\-\.\+]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/{print $0}'
}

# 判断域名
is_domain() {
  echo "$1" | gawk '/[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+/{print $0}'
}

# 判断日期时间
is_date() {
  echo "$1" | gawk '/^[1-2]{1}[0-9]{3}\-(1[0-2]|0?[1-9])\-(0?[1-9]|[1-2][0-9]|3[0-1])$/{print $0}'
}

# 判断日期时间
is_datetime() {
  echo "$1" | gawk '/^[1-2]{1}[0-9]{3}\-(1[0-2]|0?[1-9])\-(0?[1-9]|[1-2][0-9]|3[0-1])\s(2[0-3]|[0-1]?[0-9])\:([0-5]?[0-9])\:([0-5]?[0-9])$/{print $0}'
}

# 判断用户名
is_username() {
  echo "$1" | gawk '/^[a-zA-Z]{1}[0-9a-zA-Z]{3,19}$/{print $0}'
}

# 判断密码
is_password() {
  echo "$1" | gawk '/^[0-9a-zA-Z]{1}[0-9a-zA-Z\!\@\#\$\%\&\(\)\=\[\]\{\}\:\?\.\/\,\;\+]{5,29}$/{print $0}'
}

# 判断网络地址端口
is_webadress() {
  if [[ $(echo "$1" | grep -c ":") != 1 ]]; then
    return
  fi
  if [[ -n $(is_ipadress $(echo "$1" | awk -F ":" '{print $1}')) ]]; then
    if [[ -n $(is_port $(echo "$1" | awk -F ":" '{print $2}')) ]]; then
      echo "$1"
    fi
  fi
}

# 转换磁盘大小
to_size() {
  if [[ ! -n $(echo "$1" | gawk '/^[1-9]{1}[0-9]+?/{print $0}') ]]; then
    echo "--"
    return
  fi
  if [[ 1024 -gt $1 ]]; then
    echo "$1 Bytes"
  elif [[ 1028576 -gt $1 ]]; then
    echo "scale=2;print $1/1024" | bc && echo "KB"
  elif [[ 1073741824 -gt $1 ]]; then
    echo "scale=2;print $1/1024/1024" | bc && echo "MB"
  elif [[ 1073741824 -le $1 ]]; then
    echo "scale=2;print $1/1024/1024/1024" | bc && echo "GB"
  fi
}