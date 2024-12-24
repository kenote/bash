#! /bin/bash

# 获取端口转发列表
get_stream_list() {
  list=`ls $WORKDIR/stream/conf | grep -E ".conf(\.bak)?$"`
  printf "%-10s %-20s %-20s %-30s %-10s\n" "PID" "NAME" "PORT" "PROXY" "TYPE"
  echo "-----------------------------------------------------------------------------------------------------------"
  for file in ${list[@]}
  do
    pid=`get_pid $file`
    name=`get_name $file`
    port=`get_info_node $WORKDIR/stream/conf/$file listen "|udp|reuseport"`
    proxy_pass=`get_info_node $WORKDIR/stream/conf/$file proxy_pass`
    if [[ -n $(get_info_node $WORKDIR/stream/conf/$file listen | grep "udp") ]]; then
      mode="UDP"
    else
      mode="TCP"
    fi
    printf "%-10s %-20s %-20s %-30s %-10s\n" "$pid" "$name" "$port" "$proxy_pass" "$mode"
    unset pid name port proxy_pass mode
  done
  unset list file
}

# 创建端口转发
create_stream() {
  unset name udp port proxy_pass timeout connect_timeout file
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --name)
      name=$2
      shift
    ;;
    --udp)
      udp=$2
      shift
    ;;
    --proxy_pass)
      proxy_pass=$2
      shift
    ;;
    --port)
      port=$2
      shift
    ;;
    --timeout)
      timeout=$2
      shift
    ;;
    --connect_timeout)
      connect_timeout=$2
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
  file="$WORKDIR/stream/conf/$name.conf"
  # 创建配置
  echo -e "" > $file
  echo -e "server {" >> $file
  if [[ $udp == 'true' ]]; then
    echo -e "    listen $port udp reuseport;" >> $file
  else
    echo -e "    listen $port;" >> $file
  fi
  echo -e "    proxy_pass $proxy_pass;" >> $file
  if [[ -n $timeout ]]; then
    echo -e "    proxy_timeout ${timeout}s;" >> $file
  fi
  if [[ -n $connect_timeout ]]; then
    echo -e "    proxy_connect_timeout ${connect_timeout}s;" >> $file
  fi
  echo -e "}" >> $file
  unset name udp port proxy_pass timeout connect_timeout file
}

# 设置转发属性
set_stream_node() {
  file="$WORKDIR/stream/conf/$1"
  case $2 in
  port)
    sed -i "s/$(cat $file | grep "listen")/    listen $(get_info_node $file listen | sed -E "s/[0-9]{1,5}/$3/");/" $file
  ;;
  mode)
    if [[ $3 == 'udp' ]]; then
      sed -i "s/$(cat $file | grep "listen")/    listen $(get_info_node $file listen "|udp|reuseport" | sed -E 's/\s+//') udp reuseport;/" $file
    else
      sed -i "s/$(cat $file | grep "listen")/    listen $(get_info_node $file listen "|udp|reuseport" | sed -E 's/\s+//');/" $file
    fi
  ;;
  proxy_pass)
    sed -i "s/$(cat $file | grep "proxy_pass")/    proxy_pass $3;/" $file
  ;;
  timeout)
    if [[ -n $(cat $file | grep "proxy_timeout") ]]; then
      sed -i "s/$(cat $file | grep "proxy_timeout")/    proxy_timeout $3;/" $file
    else
      sed -i "s/$(cat $file | grep -E "^\}")/    proxy_timeout $3;\n\}/" $file
    fi
  ;;
  connect_timeout)
    if [[ -n $(cat $file | grep "proxy_connect_timeout") ]]; then
      sed -i "s/$(cat $file | grep "proxy_connect_timeout")/    proxy_connect_timeout $3;/" $file
    else
      sed -i "s/$(cat $file | grep -E "^\}")/    proxy_connect_timeout $3;\n\}/" $file
    fi
  ;;
  esac
}

# 端口转发选项
stream_options() {
  clear
  file="$WORKDIR/stream/conf/$1"
  echo "转发配置 -- $(get_name $1)"
  echo "------------------------"
  echo "转发端口: $(get_info_node $file listen "|udp|reuseport")"
  echo "代理地址: $(get_info_node $file proxy_pass)"
  if [[ -n $(get_info_node $file listen | grep "udp") ]]; then
    echo "传输类型: UDP"
  else
    echo "传输类型: TCP"
  fi

  upstreamfile=`ls $WORKDIR/upstream | grep -E "^(\[[0-9]{2}\])?$(get_info_node $file proxy_pass)\.(conf|hash)(\.bak)?$"`
  if [[ -n $upstreamfile ]]; then
    echo
    get_upstream_server "$upstreamfile"
  fi
  
  echo
  echo "操作选项"
  echo "----------------------------------------------------------------"
  echo "1. 设置排序编号         2. 设置转发端口         3. 设置传输类型"
  echo "4. 变更代理地址         5. 设置响应超时         6. 设置连接超时"
  echo "----------------------------------------------------------------"
  echo "11. 重启应用配置        12. 检测转发配置        13. 手动编辑配置"
  echo "14. 删除转发配置"
  echo "----------------------------------------------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  echo
  if [[ -n $3 ]]; then
    echo -e "${red}$3${plain}"
    echo
  fi
  file="$WORKDIR/stream/conf/$1"
  read -p "请输入选择: " sub_choice

  case $sub_choice in
  1)
    clear
    sub_title="设置排序编号 -- $(get_name $1)\n------------------------"
    echo -e $sub_title
    while read -p "排序编号: " pid
    do
      goback $pid "clear;stream_options $1 $2"
      if [[ ! -n $pid ]]; then
        warning "请输入新的排序编号！" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo $pid | gawk '/^[0-9a-z]{2}$/{print $0}') ]]; then
        warning "排序编号必须长度为2位的数字加英文字符！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n排序编号: $pid"
    clear && echo -e $sub_title
    echo
    mv $file "$WORKDIR/stream/conf/[$pid]$(get_name $1).conf"
    echo -e "- 排序编号已设置为 [${green}$pid${plain}]"
    echo
    read -n1 -p "按任意键继续" key
    clear
    stream_options "[$pid]$(get_name $1).conf" $2
  ;;
  2)
    clear
    sub_title="设置转发端口 -- $(get_name $1)\n------------------------"
    echo -e $sub_title
    while read -p "转发端口: " port
    do
      goback $port "clear;stream_options $1 $2"
      if [[ ! -n $port ]]; then
        warning "请填写转发端口" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_port "$port") ]]; then
        warning "请填写正确的端口" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n转发端口: $port"
    clear && echo -e $sub_title
    echo
    set_stream_node "$1" "port" "$port"
    clear
    stream_options $1 $2
  ;;
  3)
    switch_value "TCP UDP" "设置传输类型 -- $(get_name $1)\n------------------------" "clear;stream_options $1 $2"
    set_stream_node "$1" "mode" "$(echo "tcp udp" | awk -F " " "{print \$$value}")"
    clear
    stream_options $1 $2
  ;;
  4)
    clear
    sub_title="变更代理地址 -- $(get_name $1)\n------------------------"
    echo -e $sub_title
    while read -p "代理地址: " proxy_pass
    do
      goback $proxy_pass "clear;stream_options $1 $2"
      if [[ ! -n $proxy_pass ]]; then
        warning "请填写代理地址" "$sub_title"
        continue
      fi
      if [[ -n $(echo "$proxy_pass" | grep ":") ]]; then
        if [[ ! -n $(is_webadress "$proxy_pass") ]]; then
          warning "代理地址格式错误，请填写<IP:PORT>或负载均衡名称" "$sub_title"
          continue
        fi
      else
        if [[ ! -n $(echo "$proxy_pass" | gawk '/([a-zA-Z0-9_\-\.]+)$/{print $0}') ]]; then
          warning "代理地址格式错误，请填写<IP:PORT>或负载均衡名称" "$sub_title"
          continue
        fi
      fi
      break
    done
    sub_title="$sub_title\n代理地址: $proxy_pass"
    clear && echo -e $sub_title
    echo
    set_stream_node "$1" "proxy_pass" "$proxy_pass"
    clear
    stream_options $1 $2
  ;;
  5)
    clear
    sub_title="设置响应超时 -- $(get_name $1)\n------------------------"
    echo -e $sub_title
    while read -p "响应超时: " timeout
    do
      goback $timeout "clear;stream_options $1 $2"
      if [[ ! -n $timeout ]]; then
        warning "请填写响应超时时间" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$timeout" | gawk '/^[1-9]{1}[0-9]{1,2}?$/{print $0}') ]]; then
        warning "响应超时时间必须是1-999的数字" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n响应超时: $timeout"
    clear && echo -e $sub_title
    echo
    set_stream_node "$1" "timeout" "${timeout}s"
    clear
    stream_options $1 $2
  ;;
  6)
    clear
    sub_title="设置连接超时 -- $(get_name $1)\n------------------------"
    echo -e $sub_title
    while read -p "连接超时: " connect_timeout
    do
      goback $connect_timeout "clear;stream_options $1 $2"
      if [[ ! -n $connect_timeout ]]; then
        warning "请填写连接超时时间" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$connect_timeout" | gawk '/^[1-9]{1}[0-9]{1,2}?$/{print $0}') ]]; then
        warning "连接超时时间必须是1-999的数字" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n连接超时: $connect_timeout"
    clear && echo -e $sub_title
    echo
    set_stream_node "$1" "connect_timeout" "${connect_timeout}s"
    clear
    stream_options $1 $2
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
    stream_options $1 $2
  ;;
  12)
    clear
    echo "检测转发配置"
    echo "------------------------"
    echo
    nginx -t
    echo
    read -n1 -p "按任意键继续" key
    clear
    stream_options $1 $2
  ;;
  13)
    clear
    vi $file
    clear
    stream_options $1 $2
  ;;
  14)
    clear
    echo "删除转发配置"
    echo "------------------------"
    echo
    confirm "确定要删除转发配置吗?" "n"
    if [[ $? == 1 ]]; then
      clear
      stream_options $1 $2
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
    stream_options $1 $2 "请输入正确的数字"
  ;;
  esac
}