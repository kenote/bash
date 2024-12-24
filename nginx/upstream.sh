#! /bin/bash

# 获取负载均衡列表
get_upstream_list() {
  list=`ls $WORKDIR/upstream | grep -E ".(conf|hash)(\.bak)?$"`
  printf "%-22s %-32s %-42s\n" "名称" "服务" "模式"
  echo "------------------------------------------------------------------------------"
  for file in ${list[@]}
  do
    name=`get_name $file`
    type=`get_upstream_mode $file`
    server=`get_info_node $WORKDIR/upstream/$file server | awk -F " " '{print $1}'`
    printf "%-20s %-30s %-40s\n" "$name" "$server" "$(echo $type | awk -F " " '{print $1}')"
  done
  unset list file name type server
}

# 添加负载均衡
create_upstream() {
  unset name type server file
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --name)
      name=$2
      shift
    ;;
    --type)
      type=$2
      shift
    ;;
    --server)
      server="$2"
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
  file="$WORKDIR/upstream/$name.conf"
  echo -e "" > $file
  echo -e "upstream $name {" >> $file
  case $type in
  url_hash)
    echo -e "    hash \$request_uri;" >> $file
  ;;
  ip_hash | least_conn)
    echo -e "    $type;" >> $file
  ;;
  esac
  if [[ -n $server ]]; then
    echo -e "    server $server;" >> $file
  fi
  echo -e "}" >> $file
  unset name type server file
}

# 添加服务器
add_upstream_server() {
  unset name server weight maxfails failtime param file
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --name)
      name=$2
      shift
    ;;
    --server)
      server="$2"
      shift
    ;;
    --weight)
      weight=$2
      shift
    ;;
    --maxfails)
      maxfails=$2
      shift
    ;;
    --failtime)
      failtime=$2
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
  param=""
  if [[ -n $weight ]]; then
    param="$param weight=$weight"
  fi
  if [[ -n $maxfails ]]; then
    param="$param max_fails=$maxfails"
  fi
  if [[ -n $failtime ]]; then
    param="$param fail_timeout=$failtime"
  fi
  
  file="$WORKDIR/upstream/$name.conf"
  if [[ -n $(cat $file | grep "backup") ]]; then
    sed -i "/$(cat $file | grep "backup" | tail -n 1)/i\    server $server$param;" $file
  else
    sed -i "s/$(cat $file | grep -E "^\}")/    server $server$param;\n\}/" $file
  fi
  unset name server weight maxfails failtime param file
}

# 设置服务器
set_upstream_server() {
  unset name server weight maxfails failtime param file
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --name)
      name=$2
      shift
    ;;
    --server)
      server="$2"
      shift
    ;;
    --weight)
      weight=$2
      shift
    ;;
    --maxfails)
      maxfails=$2
      shift
    ;;
    --failtime)
      failtime=$2
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
  param=""
  if [[ -n $weight ]]; then
    param="$param weight=$weight"
  fi
  if [[ -n $maxfails ]]; then
    param="$param max_fails=$maxfails"
  fi
  if [[ -n $failtime ]]; then
    param="$param fail_timeout=$failtime"
  fi
  file="$WORKDIR/upstream/$name.conf"
  sed -i "s/$(cat $file | grep -E "server(\s+)$server(\s+)?" | grep -v "backup")/    server $server$param;/" $file
  unset name server weight maxfails failtime param file
}

# 获取负载均衡模式
get_upstream_mode() {
  if [[ ! -n $(cat $WORKDIR/upstream/$1 | grep -E "conn|hash") ]]; then
    echo "默认轮询"
  elif [[ -n $(cat $WORKDIR/upstream/$1 | grep "least_conn") ]]; then
    #   echo "1. 默认轮询"
    # 
    # echo "3. URL缓存命中"
    echo "最少连接负载"
  elif [[ -n $(cat $WORKDIR/upstream/$1 | grep "ip_hash") ]]; then
    echo "会话持久化"
  elif [[ -n $(cat $WORKDIR/upstream/$1 | grep "hash \$request_uri") ]]; then
    echo "URL缓存命中"
  else
    cat $WORKDIR/upstream/$1 | grep -E "conn|hash" | sed -E "s/^(\s+)|\;//g"
  fi
}

# 获取负载均衡服务
get_upstream_server() {
  file="$WORKDIR/upstream/$1"
  if [[ $2 == 'backup' ]]; then
    printf "%-25s %-10s %-10s %-15s\n" "SERVER" "WEIGHT" "MAX_FAILS" "FAIL_TIMEOUT"
    echo "-------------------------------------------------------------------"
  else
    printf "%-25s %-10s %-10s %-15s %-10s\n" "SERVER" "WEIGHT" "MAX_FAILS" "FAIL_TIMEOUT" "BACKUP"
    echo "------------------------------------------------------------------------------"
  fi
  for n in $(seq 1 $(cat $file | grep -E "(\s+)?server\s+" | wc -l));
  do
    info=`cat $file | grep -E "(\s+)?server\s+" | sed -E "s/^(\s+)|\;|(server\s+)//g" | sed -n "${n}p"`
    server=`get_upstream_server_info "$info" "server"`
    weight=`get_upstream_server_info "$info" "weight"`
    maxfails=`get_upstream_server_info "$info" "max_fails"` 
    failtime=`get_upstream_server_info "$info" "fail_timeout"`
    if [[ ! -n $weight ]]; then weight="--"; fi
    if [[ ! -n $maxfails ]]; then maxfails="--"; fi
    if [[ ! -n $failtime ]]; then failtime="--"; fi
    if [[ $2 == 'backup' ]]; then
      if [[ -n $(echo "$info" | grep "backup") ]]; then
        continue
      fi
      printf "%-25s %-10s %-10s %-15s\n" "$server" "$weight" "$maxfails" "$failtime"
    else
      if [[ -n $(echo "$info" | grep "backup") ]]; then backup="TRUE"; else backup="--"; fi
      printf "%-25s %-10s %-10s %-15s %-10s\n" "$server" "$weight" "$maxfails" "$failtime" "$backup"
    fi
    
    unset info server weight maxfails failtime backup
  done
}

# 分解负载均衡服务信息
get_upstream_server_info() {
  _info=($1)
  case $2 in
  weight | max_fails | fail_timeout)
    for item in ${_info[@]};
    do
      if [[ -n $(echo "$item" | grep "$2") ]]; then
        echo "$item" | sed 's/\(.*\)=\(.*\)/\2/g'
        break
      fi
    done
  ;;
  server)
    echo "${_info[0]}"
  ;;
  esac
  unset _info item
}

# 负载均衡模式
set_upstream_mode() {
  file="$WORKDIR/upstream/$1"
  if [[ -n $(cat $file | grep -E "conn|hash") ]]; then
    sed -i -E "/(conn|hash)/d" $file
  fi
  case $2 in
  url_hash)
    sed -i "/{/a\    hash \$request_uri consistent;" $file
  ;;
  ip_hash | least_conn)
    sed -i "/{/a\    $2;" $file
  ;;
  esac
  if [[ -n $(echo $2 | grep "hash") ]]; then
    newfile="$WORKDIR/upstream/$(get_name $1).hash"
  else
    newfile="$WORKDIR/upstream/$(get_name $1).conf"
  fi
  if [[ $file != $newfile ]]; then
    mv $file $newfile
  fi
  unset file newfile
}

# 添加备用服务器
add_upstream_backup() {
  unset name server file
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --name)
      name=$2
      shift
    ;;
    --server)
      server="$2"
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
  file="$WORKDIR/upstream/$name.conf"
  sed -i "s/$(cat $file | grep -E "^\}")/    server $server backup;\n\}/" $file
  unset name server file
}

# 负载均衡选项
upstream_options() {
  clear
  file="$WORKDIR/upstream/$1"
  echo "负载均衡 -- $(get_name $1)"
  echo "----------------------------------"
  echo "类型: $(get_upstream_mode $1)"
  echo
  get_upstream_server "$1"


  
  echo
  echo "操作选项"
  echo "----------------------------------------------------------------"
  echo "1. 设置模式         2. 添加服务器         3. 删除服务器"
  echo "4. 备用服务器       5. 编辑服务器         6. 手动编辑配置"
  echo "----------------------------------------------------------------"
  echo "11. 重启应用配置    12. 检测负载配置      13. 删除负载配置"
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
    echo "设置模式"
    echo "------------------------"
    echo
    modelist=(default ip_hash url_hash least_conn)
    echo "1. 默认轮询"
    echo "2. 会话持久化"
    echo "3. URL缓存命中"
    echo "4. 最少连接负载"
    echo
    read -p "请输入选择: " mod_choice
    case $mod_choice in
    1|2|3|4)
      set_upstream_mode "$1" "${modelist[$((mod_choice-1))]}"
      clear
      upstream_options $(ls $WORKDIR/upstream | grep -E ".(conf|hash)(\.bak)?$") $2
    ;;
    *)
      clear
      upstream_options $1 $2
    ;;
    esac
  ;;
  2)
    clear
    sub_title="添加服务器\n------------------------"
    echo -e $sub_title
    echo
    while read -p "服务器: " server
    do
      goback $server "clear;upstream_options $1 $2"
      if [[ ! -n $server ]]; then
        warning "请填写服务器" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_webadress "$server") ]]; then
        warning "服务器地址格式错误，请正确写<IP:PORT>" "$sub_title"
        continue
      fi
      if [[ -n $(cat $file | grep "$server") ]]; then
        warning "服务器地址已存在" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n服务器: $server"
    clear && echo -e $sub_title
    while read -p "权重: " weight
    do
      goback $weight "clear;upstream_options $1 $2"
      if [[ -n $weight && ! -n $(echo "$weight" | gawk '/^[1-9]{1}$/{print $0}') ]]; then
        warning "权重必须是1-9的数字" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n权重: $weight"
    clear && echo -e $sub_title
    while read -p "最大失败次数: " maxfails
    do
      goback $maxfails "clear;upstream_options $1 $2"
      if [[ -n $maxfails && ! -n $(echo "$maxfails" | gawk '/^[1-9]{1}[0-9]{1}?$/{print $0}') ]]; then
        warning "最大失败次数必须是1-99的数字" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n最大失败次数: $maxfails"
    clear && echo -e $sub_title
    while read -p "故障超时时间: " failtime
    do
      goback $failtime "clear;upstream_options $1 $2"
      if [[ -n $failtime && ! -n $(echo "$failtime" | gawk '/^[1-9]{1}[0-9]{1,2}?$/{print $0}') ]]; then
        warning "故障超时时间必须是1-999的数字" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n故障超时时间: $failtime"
    clear && echo -e $sub_title
    echo
    add_upstream_server --name "$(get_name $1)" --server "$server" --weight "$weight" --maxfails "$maxfails" --failtime "$failtime"
    clear
    upstream_options $1 $2
  ;;
  3)
    clear
    sub_title="删除服务器\n------------------------"
    echo -e $sub_title
    echo
    get_upstream_server "$1"
    echo
    while read -p "服务器: " server
    do
      goback $server "clear;upstream_options $1 $2"
      if [[ ! -n $server ]]; then
        warning "请填写服务器" "$sub_title" "get_upstream_server \"$1\""
        continue
      fi
      if [[ ! -n $(cat $file | grep -E "server(\s+)$server(\s+)?") ]]; then
        warning "查询的服务器不存在" "$sub_title" "get_upstream_server \"$1\""
        continue
      fi
      break
    done
    echo
    sed -i -E "/server(\s+)$server(\s+)?/d" $file
    clear
    upstream_options $1 $2
  ;;
  4)
    clear
    sub_title="备用服务器\n------------------------"
    echo -e $sub_title
    echo
    get_upstream_server "$1"
    echo
    while read -p "服务器: " server
    do
      goback $server "clear;upstream_options $1 $2"
      if [[ ! -n $server ]]; then
        warning "请填写服务器" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_webadress "$server") ]]; then
        warning "服务器地址格式错误，请正确写<IP:PORT>" "$sub_title"
        continue
      fi
      if [[ -n $(cat $file | grep "$server") ]]; then
        warning "服务器地址已存在" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n服务器: $server"
    clear && echo -e $sub_title
    echo
    add_upstream_backup --name "$(get_name $1)" --server "$server"
    clear
    upstream_options $1 $2
  ;;
  5)
    clear
    sub_title="编辑服务器\n------------------------"
    echo -e $sub_title
    echo
    get_upstream_server "$1" "backup"
    echo
    while read -p "服务器: " server
    do
      goback $server "clear;upstream_options $1 $2"
      if [[ ! -n $server ]]; then
        warning "请填写服务器" "$sub_title" "get_upstream_server \"$1\""
        continue
      fi
      if [[ ! -n $(cat $file | grep -E "server(\s+)$server(\s+)?" | grep -v "backup") ]]; then
        warning "查询服务器不存在" "$sub_title" "get_upstream_server \"$1\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n服务器: $server"
    clear && echo -e $sub_title
    while read -p "权重: " weight
    do
      goback $weight "clear;upstream_options $1 $2"
      if [[ -n $weight && ! -n $(echo "$weight" | gawk '/^[1-9]{1}$/{print $0}') ]]; then
        warning "权重必须是1-9的数字" "$sub_title" "get_upstream_server \"$1\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n权重: $weight"
    clear && echo -e $sub_title
    while read -p "最大失败次数: " maxfails
    do
      goback $maxfails "clear;upstream_options $1 $2"
      if [[ -n $maxfails && ! -n $(echo "$maxfails" | gawk '/^[1-9]{1}[0-9]{1}?$/{print $0}') ]]; then
        warning "最大失败次数必须是1-99的数字" "$sub_title" "get_upstream_server \"$1\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n最大失败次数: $maxfails"
    clear && echo -e $sub_title
    while read -p "故障超时时间: " failtime
    do
      goback $failtime "clear;upstream_options $1 $2"
      if [[ -n $failtime && ! -n $(echo "$failtime" | gawk '/^[1-9]{1}[0-9]{1,2}?$/{print $0}') ]]; then
        warning "故障超时时间必须是1-999的数字" "$sub_title" "get_upstream_server \"$1\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n故障超时时间: $failtime"
    clear && echo -e $sub_title
    echo
    set_upstream_server --name "$(get_name $1)" --server "$server" --weight "$weight" --maxfails "$maxfails" --failtime "$failtime"
    clear
    upstream_options $1 $2
  ;;
  6)
    clear
    vi $file
    clear
    upstream_options $1 $2
  ;;
  11)
    clear
    echo "重启应用配置"
    echo "------------------------"
    echo
    systemctl restart nginx
    systemctl status nginx
    echo
    read -n1 -p "按任意键继续" key
    clear
    upstream_options $1 $2
  ;;
  12)
    clear
    echo "检测负载配置"
    echo "------------------------"
    echo
    nginx -t
    echo
    read -n1 -p "按任意键继续" key
    clear
    upstream_options $1 $2
  ;;
  13)
    clear
    echo "删除负载配置"
    echo "------------------------"
    echo
    confirm "确定要删除负载配置吗?" "n"
    if [[ $? == 1 ]]; then
      clear
      upstream_options $1 $2
      return
    fi
    echo
    rm -rf $file
    clear
    show_menu "" $2
  ;;
  0)
    clear
    show_menu "" $2
  ;;
  *)
    clear
    upstream_options $1 $2 "请输入正确的数字"
  ;;
  esac
}