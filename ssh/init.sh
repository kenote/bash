#! /bin/bash

# 初始化环境
init_ssh() {
  # 安装必要组件
  curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install rsync tmux jq
  # 创建目录
  mkdir -p ~/kenote_ssh
  # 创建配置文件
  if [[ ! -f ~/kenote_ssh/config ]]; then
    touch ~/kenote_ssh/config
  fi
  if [[ ! -f ~/kenote_ssh/setting.json ]]; then
    echo "{\"servers\":[],\"tasks\":[]}" | jq > ~/kenote_ssh/setting.json
    read_config_save
  fi
  # 引入 ~/.ssh/config
  if !(cat ~/.ssh/config | grep -q -E "kenote_ssh/config"); then
    echo -e "Include ~/kenote_ssh/config\n$(cat ~/.ssh/config)" > ~/.ssh/config
  fi
  # 赋予目录权限
  chmod -R 600 ~/kenote_ssh/*
}

# 读取 config 并写入 setting
read_config_save() {
  config=`cat ~/kenote_ssh/setting.json | jq -r "del(.servers[])"`
  for n in $(seq 1 $(cat ~/kenote_ssh/config | grep "^Host " | wc -l))
  do
    item="{\"id\":\"$(printf "%02d" $n)\"}"
    item=`echo $item | jq -r ".name=\"$(get_config_info "^Host" $n)\""`
    item=`echo $item | jq -r ".host=\"$(get_config_info "HostName" $n)\""`
    item=`echo $item | jq -r ".port=\"$(get_config_info "Port" $n)\""`
    item=`echo $item | jq -r ".user=\"$(get_config_info "User" $n)\""`
    item=`echo $item | jq -r ".identityFile=\"$(get_config_info "IdentityFile" $n)\""`
    config=`echo $config | jq -r ".servers[$(echo $config | jq -r ".servers | length")]=$item"`
  done
  echo $config | jq > ~/kenote_ssh/setting.json
  unset config item
}

# 获取配置节点
get_config_info() {
  cat ~/kenote_ssh/config | grep "$1 " | sed -n "${2}p" | awk -F " " '{print $2}'
}
