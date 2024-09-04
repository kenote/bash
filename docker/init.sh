#! /bin/bash

init_docker() {
  mkdir -p $1/{stack,snapshot,image,volume}
  if [[ ! -f /etc/docker/daemon.json ]]; then
    wget -O /etc/docker/daemon.json $KENOTE_BASH_MIRROR/docker/conf/daemon.json
  fi
}

# 安装 docker
install_docker() {
  if (cat /etc/os-release | grep -q -E -i "rocky|alma"); then
    dnf remove -y podman buidah
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf update -y
    dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  elif (curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/[123].." &> /dev/null); then
    wget -qO- get.docker.com | bash
  else
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
  fi
  init_docker $KENOTE_DOCKER_HOME
  docker --version
  systemctl start docker
  systemctl enable docker
}

# 卸载 docker
remove_docker() {
  docker rm $(docker ps -a -q) && docker rmi $(docker images -q) && docker network 
  remove docker-ce docker-ce-cli containerd.io docker-compose-plugin &> /dev/null
  rm -rf /var/lib/docker
}

# 判断 docker 环境
is_docker_env() {
  if !(command -v docker &> /dev/null); then
    echo -e "- ${yellow}docker 未安装${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
    return
  fi
  init_docker $KENOTE_DOCKER_HOME
}


# 获取已安装源
get_mirror_list() {
  printf "%-40s %-10s\n" "MIRROR" "SPEED"
  for url in $(cat /etc/docker/daemon.json | jq -r '.["registry-mirrors"][]'| sed 's/^null$/[]/');
  do
    if (curl --connect-timeout 5 $url -s --head | head -n 1 | grep "HTTP/[123].." &> /dev/null); then
      speed=`curl -o /dev/null -s -w "%{time_total}s" $url`
    else
      speed="timeout"
    fi
    printf "%-40s %-10s\n" "$url" "$speed"
    unset speed
  done
  unset url
}

# 添加安装源
add_mirror() {
  len=`cat /etc/docker/daemon.json | jq -r '.["registry-mirrors"] | length'`
  setting=`cat /etc/docker/daemon.json | jq -r ".[\"registry-mirrors\"][$len]=\"$1\""`
  echo "$setting" | jq > /etc/docker/daemon.json
  unset len setting
}

# 删除安装源
del_mirror() {
  setting=`cat /etc/docker/daemon.json | jq -r "del(.[\"registry-mirrors\"][] | select(.==\"$1\"))"`
  echo "$setting" | jq > /etc/docker/daemon.json
  unset setting
}

# 镜像源选项
mirror_options() {
  clear
  echo "镜像源管理"
  echo "------------------------"
  echo
  get_mirror_list
  echo
  echo "操作选项"
  echo "---------------------------------------------"
  echo "1. 添加镜像源         2. 删除镜像源"
  echo "---------------------------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  echo
  if [[ -n $1 ]]; then
    echo -e "${red}$1${plain}"
    echo
  fi
  read -p "请输入选择: " sub_choice

  case $sub_choice in
  1)
    clear
    sub_title="添加镜像源\n------------------------"
    echo -e $sub_title
    while read -p "源地址: " url
    do
      goback $url "clear;mirror_options"
      if [[ ! -n $url ]]; then
        warning "请输入源地址！" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_url $url) ]]; then
        warning "请输入正确的源地址！" "$sub_title"
        continue
      fi
      if [[ -n $(cat /etc/docker/daemon.json | jq -r ".[\"registry-mirrors\"][] | select(.==\"$url\")") ]]; then
        warning "源地址已存在！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n源地址: $url"
    clear && echo -e $sub_title
    echo
    add_mirror $url
    echo -e "- ${yellow}源地址 $url 已添加${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    mirror_options
  ;;
  2)
    clear
    sub_title="删除镜像源\n------------------------"
    echo -e $sub_title
    echo
    get_mirror_list
    echo
    while read -p "源地址: " url
    do
      goback $url "clear;mirror_options"
      if [[ ! -n $url ]]; then
        warning "请输入源地址！" "$sub_title"
        continue
      fi
      if [[ ! -n $(cat /etc/docker/daemon.json | jq -r ".[\"registry-mirrors\"][] | select(.==\"$url\")") ]]; then
        warning "源地址不存在！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n源地址: $url"
    clear && echo -e $sub_title
    echo
    del_mirror $url
    echo -e "- ${yellow}源地址 $url 已删除${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    mirror_options
  ;;
  0)
    clear
    show_menu
  ;;
  *)
    clear
    mirror_options "请输入正确的数字"
  ;;
  esac
}

# 获取压缩文件列表
get_tar_list() {
  list=`ls $KENOTE_DOCKER_HOME/$1`
  printf "%-20s %-10s %-30s\n" "NAME" "SIZE" "DATE"
  echo "---------------------------------------------------------"
  for name in ${list[@]}
  do
    file="$KENOTE_DOCKER_HOME/$1/$name"
    size=`du -h $file | awk -F ' ' '{print $1}'`
    date=`date '+%Y-%m-%d %H:%M:%S' -d @$(stat -c %Y $file)`
    printf "%-20s %-10s %-30s\n" "$name" "$size" "$date"
    unset file size date
  done
  unset list name
}
