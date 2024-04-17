#! /bin/bash

# 获取站点列表
get_server_list() {
  list=`ls $CONFDIR | grep -E "*.conf(\.bak)?$"`
  printf "%-10s %-32s %-52s %-22s %-22s\n" "PID" "名称" "域名" "端口" "证书到期"
  echo "------------------------------------------------------------------------------------------------------------------------------------------"
  for file in ${list[@]}
  do
    pid=`get_pid $file`
    name=`get_name $file`
    domain=`get_info_node $CONFDIR/$file server_name`
    ipv4=(`get_info_node $CONFDIR/$file listen "|ssl|http2"`)
    cert=`get_info_node $CONFDIR/$file ssl_certificate`
    enddate=`get_cert_enddate "$cert" "+%Y-%m-%d %H:%M:%S"`
    printf "%-10s %-30s %-50s %-20s %-20s\n" "$pid" "$name" "$domain" "${ipv4[*]}" "$enddate"
    unset pid name domain ipv4 cert enddate
  done
  unset list file
}

# 从配置中获取节点属性
get_info_node() {
  if [[ ! -f $1 ]]; then
    return
  fi
  if [[ $2 == 'listen' ]]; then
    cat $1 | grep -E "\s+$2\s+[0-9]{2,5}" | sed -E "s/$2$3//g" | sed -E "s/^(\s+)|\;//g" | uniq
  else
    cat $1 | grep -E "\s+($2)\s+" | sed -E "s/($2)//" | sed -E "s/^(\s+)|\;//g" | sed -n "1p" | uniq
  fi
}

# 获取证书到期时间
get_cert_enddate() {
  if [[ ! -n $1 || ! -f $1 ]]; then
    echo "--"
    return
  fi
  date --date="$(openssl x509 -in $1 -noout -enddate | sed 's/\(.*\)=\(.*\)/\2/g')" "$2"
}

# 获取排序ID
get_pid() {
  if [[ -n $(echo "$1" | grep -o '\[.*\]' | sed -E 's/\[|\]//g') ]]; then
    echo "$1" | grep -o '\[.*\]' | sed -E 's/\[|\]//g'
  else
    echo "--"
  fi
}

# 获取名称
get_name() {
  echo $1 | sed -E "s/\.(conf|hash)(\.bak)?$//" | sed -E "s/^\[[0-9a-z]{1,2}\]//"
}

# 创建站点配置
create_server() {
  unset name domain port wwwroot
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --name)
      name=$2
      shift
    ;;
    --domain)
      if [[ -n $domain ]]; then
        domain="$domain,$2"
      else
        domain=$2
      fi
      shift
    ;;
    --port)
      port=$2
      shift
    ;;
    --wwwroot)
      wwwroot=$2
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
  file="$CONFDIR/$name.conf"
  # 创建配置
  echo -e "" > $file
  echo -e "server {" >> $file
  echo -e "    listen $port;" >> $file
  echo -e "    listen [::]:$port;" >> $file
  echo -e "    server_name $(echo $domain | sed 's/\,/ /g');" >> $file
  if [[ -n $wwwroot ]]; then
    echo -e "    root $wwwroot;" >> $file
    echo -e "    index index.html index.htm index.php;" >> $file
  fi
  echo -e "    " >> $file
  echo -e "    include $WORKDIR/proxy/$name/*.conf;" >> $file
  echo -e "    " >> $file
  echo -e "    # 日志" >> $file
  echo -e "    access_log $WORKDIR/logs/$name/access.log;" >> $file
  echo -e "    error_log $WORKDIR/logs/$name/error.log;" >> $file
  echo -e "}" >> $file
  # 创建文件
  mkdir -p "$WORKDIR/proxy/$name"
  mkdir -p "$WORKDIR/logs/$name"
  if [[ -n $wwwroot ]]; then
    mkdir -p "$wwwroot"
    if [[ ! -f "$wwwroot/index.html" ]]; then
      wget --no-check-certificate -qO "$wwwroot/index.html" $KENOTE_BASH_MIRROR/nginx/html/index.html
    fi
  fi
  unset name domain port wwwroot file
}

# 设置SSL证书
set_ssl_certificate() {
  file="$CONFDIR/$1"
  if [[ -n $(get_info_node $file ssl_certificate) ]]; then
    return
  fi
  domain=`get_info_node $file server_name | awk -F " " '{print $1}'`
  port=`get_info_node $file listen | sed -n 1p`
  echo "http://$domain:$port"
  if !(curl -s -I http://$domain:$port | grep -i "^server:" | grep "1.25" &> /dev/null); then
    http2="http2"
  fi
  cp $file "$file.http"
  # 添加HTTPS配置
  echo -e "" > $file
  echo -e "server {" >> $file
  echo -e "    listen $(get_info_node "$file.http" listen | sed -n 1p);" >> $file
  echo -e "    listen [::]:$(get_info_node "$file.http" listen | sed -n 1p);" >> $file
  echo -e "    server_name $(get_info_node "$file.http" server_name);" >> $file
  if [[ -n $(get_info_node "$file.http" root) ]]; then
    echo -e "    root $(get_info_node "$file.http" root | sed -n 1p);" >> $file
  fi
  if [[ -n $(get_info_node "$file.http" index) ]]; then
    echo -e "    index $(get_info_node "$file.http" index | sed -n 1p);" >> $file
  fi
  echo -e "    " >> $file
  echo -e "    # 日志" >> $file
  echo -e "    access_log $(get_info_node "$file.http" access_log);" >> $file
  echo -e "    error_log $(get_info_node "$file.http" error_log);" >> $file
  echo -e "}" >> $file
  echo -e "" >> $file
  echo -e "server {" >> $file
  echo -e "    listen 443 ssl $http2;" >> $file
  echo -e "    listen [::]:443 ssl $http2;" >> $file
  echo -e "    server_name $(get_info_node "$file.http" server_name);" >> $file
  if [[ -n $(get_info_node "$file.http" root) ]]; then
    echo -e "    root $(get_info_node "$file.http" root | sed -n 1p);" >> $file
  fi
  if [[ -n $(get_info_node "$file.http" index) ]]; then
    echo -e "    index $(get_info_node "$file.http" index | sed -n 1p);" >> $file
  fi
  echo -e "    " >> $file
  if [[ ! -n $http2 ]]; then
    echo -e "    http2 on;" >> $file
  fi
  echo -e "    " >> $file
  echo -e "    ssl_certificate $2;" >> $file
  echo -e "    ssl_certificate_key $3;" >> $file
  echo -e "    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;" >> $file
  echo -e "    ssl_prefer_server_ciphers on;" >> $file
  echo -e "    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;" >> $file
  echo -e "    ssl_session_cache shared:SSL:5m;" >> $file
  echo -e "    ssl_session_timeout 5m;" >> $file
  echo -e "    " >> $file
  cat "$file.http" | grep -E "\s+include\s+" | uniq >> $file
  echo -e "    " >> $file
  echo -e "    # 日志" >> $file
  echo -e "    access_log $(get_info_node "$file.http" access_log);" >> $file
  echo -e "    error_log $(get_info_node "$file.http" error_log);" >> $file
  echo -e "}" >> $file
  unset file domain port
}

# 站点选项
server_options() {
  clear
  file="$CONFDIR/$1"
  ipv4=(`get_info_node $file listen "|ssl|http2"`)
  echo "站点 -- $(get_name $1)"
  echo "------------------------"
  echo "绑定域名: $(get_info_node $file server_name)"
  echo "监听端口: ${ipv4[*]}"
  echo "证书到期: $(get_cert_enddate "$(get_info_node $file ssl_certificate)" "+%Y-%m-%d %H:%M:%S")"
  echo
  get_proxy_list "$(get_name $1)"
  
  echo
  echo "操作选项"
  echo "----------------------------------------------------------------"
  echo "1. 设置附加参数         2. 设置排序编号         3. 签发免费证书"
  echo "4. 添加虚拟目录         5. 添加反向代理         6. 设置FastCGI"
  echo "7. 添加文件缓存         8. 编辑代理模型         9. 删除代理模型"
  echo "----------------------------------------------------------------"
  echo "11. 重启应用配置        12. 检测站点配置        13. 手动编辑配置"
  echo "14. 删除站点配置"
  echo "----------------------------------------------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  echo
  if [[ -n $3 ]]; then
    echo -e "${red}$3${plain}"
    echo
  fi
  file="$CONFDIR/$1"
  read -p "请输入选择: " sub_choice

  case $sub_choice in
  1)
    clear
    echo "设置附加参数"
    echo "------------------------"
    echo "加载中..."
    echo
    sleep 3
    filename=`ls $WORKDIR/proxy/$(get_name $1) | grep -E "^(\[[0-9]{1,2}\])?setting\.conf(\.bak)?$"`
    if [[ -n $filename ]]; then
      vi $WORKDIR/proxy/$(get_name $1)/$filename
      unset filename
    else
      set_http_setting --server "$(get_name $1)"
    fi
    clear
    server_options $1 $2
  ;;
  2)
    clear
    sub_title="设置排序编号 -- $(get_name $1)\n------------------------"
    echo -e $sub_title
    while read -p "排序编号: " pid
    do
      goback $pid "clear;server_options $1 $2"
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
    mv $file "$CONFDIR/[$pid]$(get_name $1).conf"
    echo -e "- 排序编号已设置为 [${green}$pid${plain}]"
    echo
    read -n1 -p "按任意键继续" key
    clear
    server_options "[$pid]$(get_name $1).conf" $2
  ;;
  3)
    clear
    echo "签发免费证书"
    echo "------------------------"
    echo
    if [[ -n $(get_info_node $file server_name | grep "localhost") ]]; then
      echo -e "- ${yellow}绑定域名中存在本地配置，无法签发证书${plain}"
      echo
      read -n1 -p "按任意键继续" key
      clear
      server_options $1 $2
      return
    fi
    confirm "确定要签发免费证书吗?" "n"
    if [[ $? == 1 ]]; then
      clear
      server_options $1 $2
      return
    fi
    if [[ ! -f $KENOTE_ACMECTL ]]; then
      echo
      echo -e "- ${yellow}请先安装ACME.SH${plain}"
      echo
      read -n1 -p "按任意键继续" key
      clear
      server_options $1 $2
      return
    fi
    if [[ -n $(get_info_node $file ssl_certificate) ]]; then
      echo
      confirm "证书已经存在，是否需要更新?" "n"
      if [[ $? == 1 ]]; then
        clear
        server_options $1 $2
        return
      fi
    fi
    echo
    # 签发证书
    issue_cert_nginx $(get_info_node $file server_name)
    # 安装证书
    cert=`$KENOTE_ACMECTL --list  | grep -E "^$(get_info_node $file server_name | awk -F " " '{print $1}')\s+" | awk -F " " '{print $1}'`
    if [[ -n $cert ]]; then
      # 更换证书配置
      set_ssl_certificate $1 "$KENOTE_SSL_PATH/$cert/cert.crt" "$KENOTE_SSL_PATH/$cert/private.key"
      # 安装证书
      install_cert_nginx $cert
    else
      echo
      echo -e "- ${yellow}证书签发失败${plain}"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    server_options $1 $2
  ;;

  4)
    clear
    sub_title="添加虚拟目录\n------------------------"
    echo -e $sub_title
    echo
    while read -p "映射路径(/): " name
    do
      goback $name "clear;server_options $1 $2"
      if [[ ! -n $name ]]; then
        name="/"
      fi
      break
    done
    sub_title="$sub_title\n映射路径(/): ${name[*]}"
    clear && echo -e $sub_title
    while read -p "物理路径: " wwwroot
    do
      goback $wwwroot "clear;server_options $1 $2"
      if [[ ! -n $wwwroot ]]; then
        warning "请输入指向的物理路径！" "$sub_title"
        continue
      fi
      wwwroot=`parse_path $wwwroot`
      break
    done
    sub_title="$sub_title\n物理路径: $wwwroot"
    clear && echo -e $sub_title
    while read -p "防盗链域名: " valid_referers
    do
      goback "${valid_referers[*]}" "clear;server_options $1 $2"
      if [[ -n $valid_referers ]]; then
        is_param_true "is_domain" "${valid_referers[*]}"
        if [[ $? == 1 ]]; then
          warning "防盗链域名中存在格式错误" "$sub_title"
          continue
        fi
      fi
      break
    done
    sub_title="$sub_title\n防盗链域名: ${valid_referers[*]}"
    clear && echo -e $sub_title
    confirm "是否开启文件索引?" "n"
    if [[ $? == 0 ]]; then
      autoindex="on"
    fi
    echo
    create_virtual_list --server "$(get_name $1)" --name "${name[*]}" --wwwroot "$wwwroot" --valid_referers "${valid_referers[*]}" --autoindex "$autoindex"
    clear
    server_options $1 $2
  ;;
  5)
    clear
    sub_title="添加反向代理\n------------------------"
    echo -e $sub_title
    echo
    while read -p "映射路径(/): " name
    do
      goback $name "clear;server_options $1 $2"
      if [[ ! -n $name ]]; then
        name="/"
      fi
      break
    done
    sub_title="$sub_title\n映射路径(/): ${name[*]}"
    clear && echo -e $sub_title
    while read -p "代理地址: " uri
    do
      goback $uri "clear;server_options $1 $2"
      if [[ ! -n $uri ]]; then
        warning "请输入代理地址！" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_url $uri) ]]; then
        warning "请输入正确的代理地址！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n代理地址: $uri"
    clear && echo -e $sub_title
    echo
    create_reverse_proxy --server "$(get_name $1)" --name "${name[*]}" --uri "$uri"
    clear
    server_options $1 $2
  ;;
  6)
    clear
    sub_title="设置FastCGI\n------------------------"
    echo -e $sub_title
    echo
    while read -p "FastCGI(127.0.0.1:9000): " fastcgi
    do
      goback $fastcgi "clear;server_options $1 $2"
      if [[ ! -n $fastcgi ]]; then
        fastcgi="127.0.0.1:9000"
      fi
      break
    done
    sub_title="$sub_title\nFastCGI: $fastcgi"
    clear && echo -e $sub_title
    echo
    set_fast_cgi --server "$(get_name $1)" --fastcgi "$fastcgi"
    clear
    server_options $1 $2
  ;;
  7)
    clear
    sub_title="添加文件缓存\n------------------------"
    echo -e $sub_title
    echo
    while read -p "文件类型: " name
    do
      goback $name "clear;server_options $1 $2"
      if [[ ! -n $name ]]; then
        warning "请输入文件类型！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n文件类型: ${name[*]}"
    clear && echo -e $sub_title
    while read -p "缓存时间: " expires
    do
      goback $expires "clear;server_options $1 $2"
      if [[ ! -n $expires ]]; then
        warning "请设置缓存时间！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n缓存时间: $expires"
    clear && echo -e $sub_title
    echo
    create_file_cache --server "$(get_name $1)" --name "${name[*]}" --expires "$expires"
    clear
    server_options $1 $2
  ;;

  8)
    clear
    sub_title="编辑代理模型\n------------------------"
    echo -e $sub_title
    echo
    get_proxy_list "$(get_name $1)"
    echo
    while read -p "模型名称: " name
    do
      goback $name "clear;server_options $1 $2"
      if [[ ! -n $name ]]; then
        warning "请输入模型名称！" "$sub_title" "get_proxy_list \"$(get_name $1)\""
        continue
      fi
      if [[ ! -n $(ls $WORKDIR/proxy/$(get_name $1) | grep -E "^(\[[0-9]{1,2}\])?$name\.conf(\.bak)?$") ]]; then
        warning "输入的模型不存在" "$sub_title" "get_proxy_list \"$(get_name $1)\""
        continue
      fi
      filename=`ls $WORKDIR/proxy/$(get_name $1) | grep -E "^(\[[0-9]{1,2}\])?$name\.conf(\.bak)?$"`
      break
    done
    echo
    vi $WORKDIR/proxy/$(get_name $1)/$filename
    unset name filename
    clear
    server_options $1 $2
  ;;
  9)
    clear
    sub_title="删除代理模型\n------------------------"
    echo -e $sub_title
    echo
    get_proxy_list "$(get_name $1)"
    echo
    while read -p "模型名称: " name
    do
      goback $name "clear;server_options $1 $2"
      if [[ ! -n $name ]]; then
        warning "请输入模型名称！" "$sub_title" "get_proxy_list \"$(get_name $1)\""
        continue
      fi
      if [[ ! -n $(ls $WORKDIR/proxy/$(get_name $1) | grep -E "^(\[[0-9]{1,2}\])?$name\.conf(\.bak)?$") ]]; then
        warning "输入的模型不存在" "$sub_title" "get_proxy_list \"$(get_name $1)\""
        continue
      fi
      filename=`ls $WORKDIR/proxy/$(get_name $1) | grep -E "^(\[[0-9]{1,2}\])?$name\.conf(\.bak)?$"`
      break
    done
    echo
    confirm "确定要删除代理模型吗?" "n"
    if [[ $? == 0 ]]; then
      rm -rf $WORKDIR/proxy/$(get_name $1)/$filename
    fi
    unset name filename
    clear
    server_options $1 $2
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
    server_options $1 $2
  ;;
  12)
    clear
    echo "检测当前配置"
    echo "------------------------"
    echo
    nginx -t
    echo
    read -n1 -p "按任意键继续" key
    clear
    server_options $1 $2
  ;;
  13)
    clear
    vi $file
    clear
    server_options $1 $2
  ;;
  14)
    clear
    echo "删除站点配置"
    echo "------------------------"
    echo
    confirm "确定要删除站点配置吗?" "n"
    if [[ $? == 1 ]]; then
      clear
      server_options $1 $2
      return
    fi
    echo
    wwwroot=`get_info_node $file root | sed -n 1p`
    rm -rf $file
    rm -rf $WORKDIR/proxy/$(get_name $1)
    echo
    confirm "是否同时删除日志和静态文件目录?" "n"
    if [[ $? == 0 ]]; then
      if [[ -n $wwwroot && -f $wwwroot ]]; then
        rm -rf $wwwroot
      fi
      rm -rf $WORKDIR/logs/$(get_name $1)
    fi
    unset wwwroot
    systemctl restart nginx
    systemctl status nginx
    sleep 5
    clear
    show_menu "" $2
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
  unset file ipv4 sub_choice
}