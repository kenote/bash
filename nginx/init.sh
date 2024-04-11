#! /bin/bash

# 获取 nginx 环境
get_nginx_env() {
  ROOTDIR=`dirname $(find /etc /usr/local -name nginx.conf)`
  # 配置目录路径
  CONFLINK=`dirname $(cat $ROOTDIR/nginx.conf | grep "conf.d/\*.conf;" | awk -F " " '{print $2}')`
  # 配置目录真实路径
  CONFDIR=`readlink -f $CONFLINK`
  # 工作目录路径
  if [[ $CONFDIR != $CONFLINK ]]; then
    WORKDIR=`dirname $CONFDIR`
  fi
}

# 安装 nginx
install_nginx() {
  if (cat /etc/os-release | grep -q -E -i "centos"); then
    wget --no-check-certificate -qO /etc/yum.repos.d/nginx.repo $KENOTE_BASH_MIRROR/nginx/nginx.repo
  elif (cat /etc/os-release | grep -q -E -i "debian"); then
    sudo apt install -y curl gnupg2 ca-certificates lsb-release debian-archive-keyring
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
      | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
      http://nginx.org/packages/debian `lsb_release -cs` nginx" \
      | sudo tee /etc/apt/sources.list.d/nginx.list
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
      | sudo tee /etc/apt/preferences.d/99nginx
  elif (cat /etc/os-release | grep -q -E -i "ubuntu"); then
    sudo apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring
    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
      | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
      http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
      | sudo tee /etc/apt/sources.list.d/nginx.list
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
      | sudo tee /etc/apt/preferences.d/99nginx
  fi
  curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install nginx
  systemctl enable nginx
  systemctl start nginx
}

# 初始化目录
init_nginx_conf() {
  mkdir -p $1/{proxy,upstream,wwwroot,logs,stream/conf}
  if [[ $CONFDIR == $CONFLINK ]]; then
    # 备份原配置
    cp -r $CONFDIR/. $CONFLINK.bak
    # 拷贝配置文件
    cp -r $CONFLINK.bak/. $1/conf
    # 引入 setting
    sed -i 's/sendfile/#sendfile/' $ROOTDIR/nginx.conf
    sed -i 's/keepalive/#keepalive/' $ROOTDIR/nginx.conf
    wget --no-check-certificate -qO $1/setting.conf $KENOTE_BASH_MIRROR/nginx/conf/setting.conf
    sed -i "/include \/etc\/nginx\/conf.d\/\*.conf;/i\    include $1/setting.conf;" $ROOTDIR/nginx.conf
    # 引入 upstream
    if [[ ! -n $(cat $ROOTDIR/nginx.conf | grep "/upstream/\*.conf;") ]]; then
      sed -i "/include \/etc\/nginx\/conf.d\/\*.conf;/a\    include $1/upstream/\*.conf;" $ROOTDIR/nginx.conf
    fi
    if [[ ! -n $(cat $ROOTDIR/nginx.conf | grep "/upstream/\*.hash;") ]]; then
      sed -i "/include \/etc\/nginx\/conf.d\/\*.conf;/a\    include $1/upstream/\*.hash;" $ROOTDIR/nginx.conf
    fi
    # 引入 stream
    if [[ ! -n $(cat $ROOTDIR/nginx.conf | grep "/stream/index.conf;") ]]; then
      sed -i "/http {/i\include $1/stream/index.conf;\n" $ROOTDIR/nginx.conf
    fi
    if [[ ! -f $1/stream/index.conf ]]; then
      echo -e "stream {" > $1/stream/index.conf
      echo -e "    include $1/stream/conf/*.conf;" >> $1/stream/index.conf
      echo -e "    include $1/upstream/*.conf;" >> $1/stream/index.conf
      echo -e "}" >> $1/stream/index.conf
    fi
  elif [[ -n $WORKDIR ]]; then
    # 拷贝配置文件
    cp -r $WORKDIR/. $1
    rm -rf $WORKDIR
    # 替换引用
    sed -i "s/$(echo $WORKDIR | sed 's/\//\\\//g')/$(echo $1 | sed 's/\//\\\//g')/g" $ROOTDIR/nginx.conf
    sed -i "s/$(echo $WORKDIR | sed 's/\//\\\//g')/$(echo $1 | sed 's/\//\\\//g')/g" $1/conf/*.conf
    sed -i "s/$(echo $WORKDIR | sed 's/\//\\\//g')/$(echo $1 | sed 's/\//\\\//g')/g" $1/stream/index.conf
  fi
  # 删除旧软链
  rm -rf $CONFLINK
  # 创建新软链
  ln -s $1/conf $CONFLINK
  # 重启 nginx
  systemctl restart nginx
}

# 卸载 nginx
remove_nginx() {
  curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --remove nginx
  rm -rf /etc/nginx
}

# 判断 nginx 环境
is_nginx_env() {
  if !(nginx -v &> /dev/null); then
    echo -e "- ${yellow}nginx 未安装${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
    return
  fi
}

# 
read_nginx_env() {
  
  nginx -v
  echo
  NGINX_STATUS=`systemctl status nginx | grep "active" | cut -d '(' -f2|cut -d ')' -f1`
}