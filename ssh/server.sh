#! /bin/bash

# 服务器列表
server_list() {
  if [[ $1 == 'online' ]]; then
    printf "%-5s %-16s %-20s %-12s %-12s %-18s %-16s %-16s %-12s\n" "ID" "名称" "主机" "端口" "状态" "响应时间" "地区" "城市" "国家"
    echo "-------------------------------------------------------------------------------------------------------------------"
  else
    printf "%-5s %-16s %-20s %-12s %-16s %-16s %-12s\n" "ID" "名称" "主机" "端口" "地区" "城市" "国家"
    echo "-----------------------------------------------------------------------------------------"
  fi
  if [[ -n $2 ]]; then
    list=(`cat ~/kenote_ssh/setting.json | jq -r ".servers[].name | scan(\".*$(echo "$2" | sed -E 's/^(\?)//').*\")"`)
  else
    list=(`cat ~/kenote_ssh/setting.json | jq -r ".servers[].name"`)
  fi
  for name in ${list[@]}
  do
    server=`cat ~/kenote_ssh/setting.json | jq -r ".servers[] | select(.name==\"$name\")"`
    id=`echo $server | jq -r ".id"`
    host=`echo $server | jq -r ".host"`
    port=`echo $server | jq -r ".port"`
    if [[ $1 == 'online' ]]; then
      if (ping $host -c 1 -t 5 | grep "time" &> /dev/null); then
        online="在线"
        time="$(ping $host -c 1 -t 1 | grep "time" | awk -F " " '{print $7}' | awk -F "=" '{print $2}') ms"
      else
        online="离线"
        time="--"
      fi
    fi
    ipinfo=`curl -s https://ipinfo.io/$host`
    region=`echo $ipinfo | jq -r ".region" | sed 's/null/--/'`
    city=`echo $ipinfo | jq -r ".city" | sed 's/null/--/'`
    country=`echo $ipinfo | jq -r ".country" | sed 's/null/--/'`
    if [[ $1 == 'online' ]]; then
      printf "%-5s %-14s %-18s %-10s %-12s %-14s %-14s %-14s %-10s\n" "$id" "$name" "$host" "$port" "$online" "$time" "${region[*]}" "${city[*]}" "$country"
    else
      printf "%-5s %-14s %-18s %-10s %-14s %-14s %-10s\n" "$id" "$name" "$host" "$port" "${region[*]}" "${city[*]}" "$country"
    fi
  done
  unset id name host port online time list ipinfo region city country
}

# 添加服务器
create_server() {
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --name)
      name=$2
      shift
    ;;
    --address)
      address=$2
      shift
    ;;
    --port)
      port=$2
      shift
    ;;
    --user)
      user=$2
      shift
    ;;
    *)
      echo -e "${red}Unknown parameter : $1${plain}"
      return 1
      shift
    ;;
    esac
    shift 1
  done
  if [[ ! -n $port ]]; then
    port=22
  fi
  if [[ ! -n $user ]]; then
    user="root"
  fi
  # 生成私钥
  identityFile="$(parse_path ~/kenote_ssh)/$name"
  ssh-keygen -t rsa -C "Kenote" -f $identityFile
  # 写入配置
  id=`echo $(($(cat ~/kenote_ssh/setting.json | jq -r ".servers[-1].id" | awk '{print int($0)}')+1))`
  server="{\"id\":\"$(printf "%02d" $id)\",\"name\":\"$name\"}"
  server=`echo $server | jq -r ".host=\"$address\""`
  server=`echo $server | jq -r ".port=\"$port\""`
  server=`echo $server | jq -r ".user=\"$user\""`
  server=`echo $server | jq -r ".identityFile=\"$identityFile\""`
  config=`cat ~/kenote_ssh/setting.json | jq -r ".servers[$(cat ~/kenote_ssh/setting.json | jq -r ".servers | length")]=$server"`
  echo $config | jq > ~/kenote_ssh/setting.json
  # 写入 config
  echo -e "" >> ~/kenote_ssh/config
  echo -e "Host $name" >> ~/kenote_ssh/config
  echo -e "    HostName $address" >> ~/kenote_ssh/config
  echo -e "    Port $port" >> ~/kenote_ssh/config
  echo -e "    User $user" >> ~/kenote_ssh/config
  echo -e "    IdentityFile $identityFile" >> ~/kenote_ssh/config
  # 上传公钥
  ssh-copy-id -i $identityFile.pub -p $port $user@$address
  # 完成添加
  echo
  echo "- 服务器已添加"
  echo
  echo "如果登录服务器还提示输入密码，请在远端服务器执行以下指令"
  echo "------------------------------------------------------------------------------------------"
  echo "sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config"
  echo "sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
  echo "sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config"
  echo "systemctl restart sshd"
  echo "------------------------------------------------------------------------------------------"
  echo
}

# 移除服务器
del_server() {
  server=`cat ~/kenote_ssh/setting.json | jq -r ".servers[] | select(.id==\"$1\")"`
  if [[ ! -n $server ]]; then
    return 1
  fi
  # 删除配置条目
  config=`cat ~/kenote_ssh/setting.json | jq -r "del(.servers[] | select(.name==\"$1\"))"`
  echo $config | jq > ~/kenote_ssh/setting.json
  # 删除 config 中数据
  start=`cat ~/kenote_ssh/config | grep -n "^Host $1" | awk -F ":" '{print $1}'`
  sed_text "$start,$(($start+5))d" ~/kenote_ssh/config
}

# 获取服务器名称
get_server_name() {
  if [[ -n $(echo "$1" | gawk '/^(rsync)/{print $0}') ]]; then
    cmd=($1)
    for n in ${cmd[@]}
    do
      if [[ -n $(echo $n | grep ":") ]]; then
        echo $n | awk -F ":" '{print $1}'
        break
      fi
    done
  else
    echo "$1" | awk -F " " '{print $2}'
  fi
}

# 获取传输文件路径
get_transport_file() {
  if [[ -n $(echo "$2" | gawk '/^(rsync)/{print $0}') ]]; then
    cmd=($2)
    case $1 in
    source)
      get_remote_path "${cmd[${#cmd[*]}-2]}"
    ;;
    target)
      get_remote_path "${cmd[${#cmd[*]}-1]}"
    ;;
    esac
  else
    echo "--"
  fi
}

# 获取远端路径
get_remote_path() {
  if [[ -n $(echo "$1" | grep ":") ]]; then
    echo "$1" | awk -F ":" '{print $2}'
  else
    echo "$1"
  fi
}

# 服务器操作
server_options() {
  clear_tasks
  clear
  server=`cat ~/kenote_ssh/setting.json | jq -r ".servers[] | select(.id==\"$1\")"`
  host=`echo $server | jq -r ".host"`
  echo "服务器 -- [$1] $(echo $server | jq -r ".name")"
  echo "------------------------"
  echo "主机: $host"
  if (ping $host -c 1 -t 3 | grep "time" &> /dev/null); then
    echo -e "状态: ${green}在线${plain}"
    echo -e "延迟: ${yellow}$(ping $host -c 1 -t 5 | grep "time" | awk -F " " '{print $7}' | awk -F "=" '{print $2}') ms${plain}"
  else
    echo -e "状态: ${red}离线${plain}"
  fi
  ipinfo=`curl -s https://ipinfo.io/$host`
  if (echo $ipinfo | jq -r ".country" | grep -v "null" &> /dev/null); then
    echo "国家: $(echo $ipinfo | jq -r ".country")"
  fi
  if (echo $ipinfo | jq -r ".region" | grep -v "null" &> /dev/null); then
    echo "地区: $(echo $ipinfo | jq -r ".region")"
  elif (echo $ipinfo | jq -r ".bogon" &> /dev/null); then
    echo "地区: 局域网"
  fi
  if (echo $ipinfo | jq -r ".city" | grep -v "null" &> /dev/null); then
    echo "城市: $(echo $ipinfo | jq -r ".city")"
  fi
  echo
  task_list "$(echo $server | jq -r ".name")"
  
  echo
  echo
  echo "操作选项"
  echo "----------------------------------------------------------------"
  echo "1. 连接服务器           2. 上传文件            3. 下载文件"
  echo "4. 移除服务器           5. 上传公钥"
  echo "----------------------------------------------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  echo
  if [[ -n $3 ]]; then
    echo -e "${red}$3${plain}"
    echo
  fi
  read -p "请输入选择: " sub_choice 

  case $sub_choice in
  1)
    clear
    create_task --type "connect" --command "ssh $(echo $server | jq -r ".name")"
    clear_tasks
    clear
    server_options $1 $2
  ;;
  2)
    clear
    sub_title="上传文件 -- [$1] $(echo $server | jq -r ".name")\n------------------------"
    echo -e $sub_title
    while read -p "文件目录路径: " uploadfile
    do
      goback $uploadfile "clear;server_options $1 $2"
      if [[ ! -n $uploadfile ]]; then
        warning "请输入文件目录路径！" "$sub_title"
        continue
      fi
      if [[ ! -f $(parse_path "$uploadfile") && ! -d $(parse_path "$uploadfile") ]]; then
        warning "文件目录路径不存在！" "$sub_title"
        continue
      fi
      break
    done
    uploadfile=$(parse_path "$uploadfile")
    sub_title="$sub_title\n文件目录路径: $uploadfile"
    clear && echo -e $sub_title
    while read -p "远端目标路径: " remotepath
    do
      goback $remotepath "clear;server_options $1 $2"
      if [[ ! -n $remotepath ]]; then
        warning "请输入远端目标路径！" "$sub_title"
        continue
      fi
      break
    done
    remotepath=$(ssh $(echo $server | jq -r ".name") "eval echo $remotepath")
    sub_title="$sub_title\n远端目标路径: $remotepath"
    clear && echo -e $sub_title
    echo
    # 如果上传目录
    if [[ -d $uploadfile ]]; then
      uploadfile=`echo $uploadfile | sed -E 's/(\/){1,3}$//'`
      # 是否存在忽略配置文件
      if [[ -f "$uploadfile/.ignore" ]]; then
        ignoreFile="--exclude-from='$uploadfile/.ignore'"
      fi
      create_task --type "upload" --command "rsync -avP -e ssh $ignoreFile $uploadfile $(echo $server | jq -r ".name"):$remotepath"
    # 如果上传文件
    elif [[ -f $uploadfile ]]; then
      filename=${uploadfile##*/}
      remotefile="$(echo $remotepath | sed -E 's/(\/){1,3}$//')/$filename"
      create_task --type "upload" --command "rsync -avP -e ssh $uploadfile $(echo $server | jq -r ".name"):$remotefile"
    fi
    clear_tasks
    unset sub_title uploadfile remotepath filename remotefile
    clear
    server_options $1 $2
  ;;
  3)
    clear
    sub_title="下载文件 -- [$1] $(echo $server | jq -r ".name")\n------------------------"
    echo -e $sub_title
    while read -p "远端文件目录: " remotepath
    do
      goback $remotepath "clear;server_options $1 $2"
      if [[ ! -n $remotepath ]]; then
        warning "请输入远端文件目录！" "$sub_title"
        continue
      fi
      if [[ ! -n $(ssh $(echo $server | jq -r ".name") "[[ -d $remotepath || -f $remotepath ]] && echo 1") ]]; then
        warning "远端文件目录不存在！" "$sub_title"
        continue
      fi
      break
    done
    remotepath=$(ssh $(echo $server | jq -r ".name") "eval echo $remotepath")
    sub_title="$sub_title\n远端文件目录: $remotepath"
    clear && echo -e $sub_title
    while read -p "下载保存路径: " downpath
    do
      goback $downpath "clear;server_options $1 $2"
      if [[ ! -n $downpath ]]; then
        warning "请输入下载保存路径！" "$sub_title"
        continue
      fi
      break
    done
    downpath=$(parse_path "$downpath")
    sub_title="$sub_title\n下载保存路径: $downpath"
    clear && echo -e $sub_title
    echo
    # 如果下载目录
    if [[ -n $(ssh $(echo $server | jq -r ".name") "[[ -d $remotepath ]] && echo 1") ]]; then
      mkdir -p $downpath
      remotepath=`echo $remotepath | sed -E 's/(\/){1,3}$//'`
      create_task --type "download" --command "rsync -avP -e ssh $(echo $server | jq -r ".name"):$remotepath $downpath"
    # 如果下载文件
    elif [[ -n $(ssh $(echo $server | jq -r ".name") "[[ -f $remotepath ]] && echo 1") ]]; then
      filename=${remotepath##*/}
      downfile="$(echo $downpath | sed -E 's/(\/){1,3}$//')/$filename"
      create_task --type "download" --command "rsync -avP -e ssh $(echo $server | jq -r ".name"):$remotepath $downfile"
    fi
    clear_tasks
    unset sub_title remotepath downpath filename downfile
    clear
    server_options $1 $2
  ;;
  4)
    clear
    echo "移除服务器 -- [$1] $(echo $server | jq -r ".name")"
    echo "------------------------"
    confirm "确定要移除服务器吗?" "n"
    if [[ $? == 0 ]]; then
      del_server "$(echo $server | jq -r ".name")"
      echo
      echo -e "- ${yellow}服务器 - [$(echo $server | jq -r ".name")] 已被移除${plain}"
      echo
      read  -n1 -p "按任意键继续" key
      clear
      show_menu "" $2
    else
      clear
      server_options $1 $2
    fi
  ;;
  5)
    clear
    echo "上传公钥 -- [$1] $(echo $server | jq -r ".name")"
    echo "------------------------"
    confirm "确定要上传公钥到服务器吗?" "n"
    if [[ $? == 0 ]]; then
      if [[ ! -f ~/kenote_ssh/$(echo $server | jq -r ".name").pub ]]; then
        ssh-keygen -t rsa -C "Kenote" -f ~/kenote_ssh/$(echo $server | jq -r ".name")
        chmod -R 600 ~/kenote_ssh/*
      fi
      s_port=`echo $server | jq -r ".port"`
      s_user=`echo $server | jq -r ".user"`
      ssh-copy-id -i ~/kenote_ssh/$(echo $server | jq -r ".name").pub -p $s_port $s_user@$host
      unset s_port s_user
      echo
      read  -n1 -p "按任意键继续" key
    fi
    clear
    server_options $1 $2
  ;;
  0)
    clear
    show_menu "" $2
  ;;
  *)
    clear
    server_options $1 $2 "请输入正确的数字"
  ;;
  esac
  unset server host ipinfo sub_choice
}