#! /bin/bash

# 获取代理列表
get_proxy_list() {
  proxydir="$WORKDIR/proxy/$1"
  if [[ ! -d $proxydir || ! -n $1 ]]; then
    return
  fi
  list=`ls $proxydir`
  printf "%-10s %-20s %-30s %-20s\n" "NAME" "TYPE" "LOCATION" "VALUE"
  echo "------------------------------------------------------------------------------------------------------------"
  for file in ${list[@]}
  do
    name=`get_name $file`
    location=`cat $proxydir/$file | grep "location" | sed -E "s/location|\{|\s+//g" | sed -n "1p"`
    proxy_pass=`get_info_node $proxydir/$file proxy_pass`
    fastcgi_pass=`get_info_node $proxydir/$file fastcgi_pass`
    expires=`get_info_node $proxydir/$file expires`
    wwwroot=`get_info_node $proxydir/$file "alias|root"`
    if [[ -n $proxy_pass ]]; then
      type="Reverse"
      mapping=$proxy_pass
    elif [[ -n $fastcgi_pass ]]; then
      type="FastCGI"
      mapping=$fastcgi_pass
    elif [[ -n $expires ]]; then
      type="FileCache"
      mapping=$wwwroot
    elif [[ -n $wwwroot ]]; then
      type="Virtical"
      mapping=$wwwroot
    else
      type="None"
      mapping="--"
    fi
    printf "%-10s %-20s %-30s %-20s\n" "$name" "$type" "$location" "$mapping"
    unset name location
  done
  unset list file proxydir proxy_pass fastcgi_pass expires wwwroot type mapping
}

# 设置附加参数
set_http_setting() {
  unset proxydir server
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --server)
      server=$2
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
  if [[ ! -n $server ]]; then
    return
  fi
  proxydir="$WORKDIR/proxy/$server"
  mkdir -p $proxydir
  echo "# 附加参数" > $proxydir/[00]setting.conf
  vi $proxydir/[00]setting.conf
  unset proxydir server
}

# 添加反向代理
create_reverse_proxy() {
  unset proxydir server name uri filename
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --server)
      server=$2
      shift
    ;;
    --name)
      name="$2"
      shift
    ;;
    --uri)
      uri="$2"
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
  if [[ ! -n $server ]]; then
    return
  fi
  proxydir="$WORKDIR/proxy/$server"
  filename="[01]$(echo $RANDOM | sha512sum | head -c 5).conf"
  mkdir -p $proxydir
  echo -e "" > $proxydir/$filename
  echo -e "location ${name[*]} {" >> $proxydir/$filename
  echo -e "    proxy_pass $uri;" >> $proxydir/$filename
  echo -e "    proxy_redirect off;" >> $proxydir/$filename
  echo -e "    proxy_set_header X-Real-IP \$remote_addr;" >> $proxydir/$filename
  echo -e "    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> $proxydir/$filename
  echo -e "    proxy_set_header Host \$http_host;" >> $proxydir/$filename
  echo -e "    proxy_set_header X-NginX-Proxy ture;" >> $proxydir/$filename
  echo -e "    proxy_http_version 1.1;" >> $proxydir/$filename
  echo -e "    proxy_set_header Upgrade \$http_upgrade;" >> $proxydir/$filename
  echo -e "    proxy_set_header Connection \"upgrade\";" >> $proxydir/$filename
  echo -e "}" >> $proxydir/$filename
  unset proxydir server name uri filename
}

# 设置FastCGI
set_fast_cgi() {
  unset proxydir server fastcgi filename
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --server)
      server=$2
      shift
    ;;
    --fastcgi)
      fastcgi="$2"
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
  if [[ ! -n $server ]]; then
    return
  fi
  proxydir="$WORKDIR/proxy/$server"
  filename="[98]fastcgi.conf"
  mkdir -p $proxydir
  echo -e "" > $proxydir/$filename
  echo -e "location ~ \.php {" >> $proxydir/$filename
  echo -e "    fastcgi_pass $fastcgi;" >> $proxydir/$filename
  echo -e "    fastcgi_index index.php;" >> $proxydir/$filename
  echo -e "    fastcgi_param SCRIPT_FILENAME /scripts\$fastcgi_script_name;" >> $proxydir/$filename
  echo -e "    include fastcgi_params;" >> $proxydir/$filename
  echo -e "}" >> $proxydir/$filename
  unset proxydir server fastcgi filename
}

# 添加虚拟目录
create_virtual_list() {
  unset proxydir server name autoindex wwwroot valid_referers filename
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --server)
      server=$2
      shift
    ;;
    --name)
      name="$2"
      shift
    ;;
    --wwwroot)
      wwwroot="$2"
      shift
    ;;
    --autoindex)
      autoindex=$2
      shift
    ;;
    --valid_referers)
      valid_referers=$2
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
  if [[ ! -n $server ]]; then
    return
  fi
  proxydir="$WORKDIR/proxy/$server"
  filename="[01]$(echo $RANDOM | sha512sum | head -c 5).conf"
  mkdir -p $proxydir
  echo -e "" > $proxydir/$filename
  echo -e "location ${name[*]} {" >> $proxydir/$filename
  if [[ $name == "/" ]]; then
    echo -e "    root $wwwroot;" >> $proxydir/$filename
  else
    echo -e "    alias $wwwroot;" >> $proxydir/$filename
  fi
  echo -e "    index index.html index.htm;" >> $proxydir/$filename
  echo -e "    " >> $proxydir/$filename
  if [[ -n $autoindex ]]; then
    echo -e "    autoindex $autoindex;" >> $proxydir/$filename
  fi
  echo -e "    charset utf-8;" >> $proxydir/$filename
  if [[ $autoindex == "on" ]]; then
    echo -e "    " >> $proxydir/$filename
    echo -e "    types {" >> $proxydir/$filename
    echo -e "        text/plain txt md sh conf repo json js jsx ts tsx vue yml yaml tpl njk mjml py php css sass scss less lua;" >> $proxydir/$filename
    echo -e "    }" >> $proxydir/$filename
  fi
  if [[ -n $valid_referers ]]; then
    echo -e "    " >> $proxydir/$filename
    echo -e "    valid_referers none blocked ${valid_referers[*]};" >> $proxydir/$filename
    echo -e "    if (\$invalid_referer) {" >> $proxydir/$filename
    echo -e "        return 403;" >> $proxydir/$filename
    echo -e "        break;" >> $proxydir/$filename
    echo -e "    }" >> $proxydir/$filename
  fi
  echo -e "}" >> $proxydir/$filename
  unset proxydir server name autoindex wwwroot valid_referers filename
}

# 文件缓存
create_file_cache() {
  unset proxydir server name expires filename
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --server)
      server=$2
      shift
    ;;
    --name)
      name="$2"
      shift
    ;;
    --expires)
      expires="$2"
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
  if [[ ! -n $server ]]; then
    return
  fi
  proxydir="$WORKDIR/proxy/$server"
  filename="[99]$(echo $RANDOM | sha512sum | head -c 5).conf"
  mkdir -p $proxydir
  echo -e "" > $proxydir/$filename
  echo -e "location ~ \.($(echo ${name[*]} | sed -E "s/\s+/\|/g" ))$ {" >> $proxydir/$filename
  echo -e "    expires $expires;" >> $proxydir/$filename
  echo -e "}" >> $proxydir/$filename
  unset proxydir server name expires filename
}