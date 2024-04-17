#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh
source $(cd $(dirname $0);pwd)/cert/acme.sh
source $(cd $(dirname $0);pwd)/nginx/init.sh
source $(cd $(dirname $0);pwd)/nginx/server.sh
source $(cd $(dirname $0);pwd)/nginx/proxy.sh
source $(cd $(dirname $0);pwd)/nginx/stream.sh
source $(cd $(dirname $0);pwd)/nginx/upstream.sh


show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> Nginx管理"
    echo "------------------------"
    echo "1. 添加站点"
    echo "2. 管理站点"
    echo "3. 添加负载均衡"
    echo "4. 管理负载均衡"
    echo "5. 添加TCP转发"
    echo "6. 添加UDP转发"
    echo "7. 管理端口转发"
    echo "------------------------"
    echo "11. 启动服务"
    echo "12. 停止服务"
    echo "13. 重启服务"
    echo "14. 检测配置"
    echo "------------------------"
    echo "00. 安装nginx"
    echo "99. 卸载nginx"
    echo "------------------------"
    echo "0. 返回主菜单"
    echo "------------------------"
    echo
    if [[ -n $1 ]]; then
      echo -e "${red}$1${plain}"
      echo
    fi
    read -p "请输入选择: " choice 
  fi

  case $choice in
  1)
    clear
    is_nginx_env
    get_nginx_env
    sub_title="添加站点\n------------------------"
    echo -e $sub_title
    while read -p "域名: " domain
    do
      goback $domain "clear;show_menu"
      if [[ -n $domain ]]; then
        is_param_true "is_domain" "${domain[*]}"
        if [[ $? == 1 ]]; then
          warning "绑定域名中存在格式错误" "$sub_title"
          continue
        fi
        name=`echo "${domain[*]}" | awk -F " " '{print $1}'`
        if [[ -n $(ls $CONFDIR | grep -E "^(\[[0-9]{2}\])?$name\.conf(\.bak)?$") ]]; then
          warning "存在相同域名配置" "$sub_title"
          continue
        fi
      else
        domain="localhost"
      fi
      break
    done
    sub_title="$sub_title\n域名: ${domain[*]}"
    clear && echo -e $sub_title
    while read -p "端口(80): " port
    do
      goback $port "clear;show_menu"
      if [[ ! -n $port ]]; then
        port=80
      fi
      if [[ ! -n $(is_port "$port") && -n $port ]]; then
        warning "请填写正确的端口" "$sub_title"
        continue
      fi
      if [[ $domain == "localhost" && $port == "80" ]]; then
        warning "您没有设定域名，为了避免冲突请选择其他端口" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n端口(80): $port"
    clear && echo -e $sub_title
    while read -p "静态目录: " wwwroot
    do
      goback $wwwroot "clear;show_menu"
      if [[ -n $wwwroot ]]; then
        wwwroot=`parse_path $wwwroot`
      fi
      break
    done
    sub_title="$sub_title\n静态目录: $wwwroot"
    clear && echo -e $sub_title
    if [[ $domain == "localhost" ]]; then
      while read -p "配置命名: " name
      do 
        goback $name "clear;show_menu"
        if [[ ! -n $name ]]; then
          warning "请为配置命名" "$sub_title"
          continue
        fi
        if [[ ! -n $(echo "$name" | gawk '/([a-zA-Z0-9_\-\.]+)$/{print $0}') ]]; then
          warning "命名请用英文字母数字下划线中划线组成" "$sub_title"
          continue
        fi
        if [[ -n $(ls $CONFDIR | grep -E "^(\[[0-9]{2}\])?$name\.conf(\.bak)?$") ]]; then
          warning "命名名称已存在" "$sub_title"
          continue
        fi
        break
      done
      sub_title="$sub_title\n配置命名: $name"
      clear && echo -e $sub_title
    fi
    echo
    # 创建配置及文件
    create_server $(to_array_param --domain "${domain[*]}") --port $port --wwwroot "$wwwroot" --name "$name"
    echo
    echo -e "- ${yellow}站点配置已添加${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    clear
    is_nginx_env
    echo "管理站点"
    echo "------------------------"
    echo
    get_nginx_env
    get_server_list
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "输入名称: " name
    do
      goback $name "clear;show_menu" "show_menu \"\" 2"
      if [[ ! -n $name ]]; then
        show_menu "" 2 "请输入名称"
        continue
      fi
      if [[ ! -n $(ls $CONFDIR | grep -E "^(\[[0-9]{2}\])?$name\.conf(\.bak)?$") ]]; then
        show_menu "" 2 "输入的名称不存在"
        continue
      fi
      break
    done
    echo
    
    server_options "$(ls $CONFDIR | grep -E "^(\[[0-9]{2}\])?$name\.conf(\.bak)?$")" 2

    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  3)
    clear
    is_nginx_env
    get_nginx_env
    sub_title="添加负载均衡\n------------------------"
    echo -e $sub_title
    while read -p "名称: " name
    do
      goback $name "clear;show_menu"
      if [[ ! -n $name ]]; then
        warning "请填写名称" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$name" | gawk '/([a-zA-Z0-9_]+)$/{print $0}') ]]; then
        warning "名称请用英文字母数字下划线组成" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n名称: $name"
    clear && echo -e $sub_title
    while read -p "服务器: " server
    do
      goback $server "clear;show_menu"
      if [[ ! -n $server ]]; then
        warning "请填写服务器" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_webadress "$server") ]]; then
        warning "服务器地址格式错误，请正确写<IP:PORT>" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n服务器: $server"
    clear && echo -e $sub_title
    echo
    create_upstream --name "$name" --server "$server"
    echo
    echo -e "- ${yellow}站点配置已添加${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  4)
    clear
    is_nginx_env
    echo "管理负载均衡"
    echo "------------------------"
    echo
    get_nginx_env
    get_upstream_list
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "输入名称: " name
    do
      goback $name "clear;show_menu" "show_menu \"\" 4"
      if [[ ! -n $name ]]; then
        show_menu "" 4 "请输入名称"
        continue
      fi
      if [[ ! -n $(ls $WORKDIR/upstream | grep -E "^(\[[0-9]{2}\])?$name\.(conf|hash)(\.bak)?$") ]]; then
        show_menu "" 4 "输入的名称不存在"
        continue
      fi
      break
    done
    echo

    upstream_options "$(ls $WORKDIR/upstream | grep -E "^(\[[0-9]{2}\])?$name\.(conf|hash)(\.bak)?$")" 4

    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  5|6)
    clear
    is_nginx_env
    get_nginx_env
    case $choice in
    5)
      sub_title="添加TCP转发\n------------------------"
      udp_mode=""
    ;;
    6)
      sub_title="添加UDP转发\n------------------------"
      udp_mode="true"
    ;;
    esac
    echo -e $sub_title

    echo
    while read -p "转发端口: " port
    do
      goback $port "clear;show_menu"
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
    while read -p "代理地址: " proxy_pass
    do
      goback $proxy_pass "clear;show_menu"
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
    while read -p "响应超时: " timeout
    do
      goback $timeout "clear;show_menu"
      if [[ -n $timeout && ! -n $(echo "$timeout" | gawk '/^[1-9]{1}[0-9]{1,2}?$/{print $0}') ]]; then
        warning "响应超时时间必须是1-999的数字" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n响应超时: $timeout"
    clear && echo -e $sub_title
    while read -p "连接超时: " connect_timeout
    do
      goback $connect_timeout "clear;show_menu"
      if [[ -n $connect_timeout && ! -n $(echo "$connect_timeout" | gawk '/^[1-9]{1}[0-9]{1,2}?$/{print $0}') ]]; then
        warning "连接超时时间必须是1-999的数字" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n连接超时: $connect_timeout"
    clear && echo -e $sub_title
    while read -p "配置命名: " name
    do 
      goback $name "clear;show_menu"
      if [[ ! -n $name ]]; then
        warning "请为配置命名" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$name" | gawk '/([a-zA-Z0-9_\-\.]+)$/{print $0}') ]]; then
        warning "命名请用英文字母数字下划线中划线组成" "$sub_title"
        continue
      fi
      if [[ -n $(ls $WORKDIR/stream/conf | grep -E "^(\[[0-9]{2}\])?$name\.conf(\.bak)?$") ]]; then
        warning "命名名称已存在" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n配置命名: $name"
    clear && echo -e $sub_title
    echo
    create_stream --name "$name" --port "$port" --proxy_pass "$proxy_pass" --timeout "$timeout" --connect_timeout "$connect_timeout" --udp "$udp_mode"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  7)
    clear
    is_nginx_env
    echo "管理端口转发"
    echo "------------------------"
    echo
    get_nginx_env
    get_stream_list
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "输入名称: " name
    do
      goback $name "clear;show_menu" "show_menu \"\" 7"
      if [[ ! -n $name ]]; then
        show_menu "" 7 "请输入名称"
        continue
      fi
      if [[ ! -n $(ls $WORKDIR/stream/conf | grep -E "^(\[[0-9]{2}\])?$name\.conf(\.bak)?$") ]]; then
        show_menu "" 7 "输入的名称不存在"
        continue
      fi
      break
    done
    echo
    
    stream_options "$(ls $WORKDIR/stream/conf | grep -E "^(\[[0-9]{2}\])?$name\.conf(\.bak)?$")" 7

    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;

  11)
    clear
    is_nginx_env
    if [[ $(systemctl status nginx | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'running' ]]; then
      systemctl restart nginx
    else
      systemctl start nginx
    fi
    systemctl status nginx
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  12)
    clear
    is_nginx_env
    if [[ $(systemctl status nginx | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'running' ]]; then
      systemctl stop nginx
    fi
    systemctl status nginx
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  13)
    clear
    is_nginx_env
    systemctl restart nginx
    systemctl status nginx
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  14)
    clear
    echo "检测配置"
    echo "------------------------"
    echo
    is_nginx_env
    nginx -t
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  00)
    clear
    if !(nginx -v &> /dev/null); then
      echo
      install_nginx
    fi
    get_nginx_env
    if [[ $CONFDIR == $CONFLINK ]]; then
      echo
      init_nginx_conf $KENOTE_NGINX_HOME
    fi
    echo
    echo -e "- ${green}初始化完成${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  99)
    clear
    if (nginx -v &> /dev/null); then
      echo
      confirm "确定要卸载 nginx 吗?" "n"
      if [[ $? == 0 ]]; then
        remove_nginx
        echo
        echo -e "- ${green}nginx 卸载完成${plain}"
      else
        clear
        show_menu
        return
      fi
    else
      echo
      echo -e "- ${yellow}nginx 尚未安装${plain}"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  0)
    run_script start.sh
  ;;
  *)
    clear
    show_menu "请输入正确的数字"
  ;;
  esac
}

clear
show_menu
