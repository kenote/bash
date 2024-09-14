#!/bin/bash

config=/usr/local/x-ui/bin/config.json
step=5

# 获取nginx环境
get_nginx_env() {
  rootdir=`find /etc /usr/local -name nginx.conf | sed -e 's/\/nginx\.conf//'`
  if [[ $rootdir == '' ]]; then
    return 1
  fi
  conflink=`cat ${rootdir}/nginx.conf | grep "conf.d/\*.conf;" | sed -e 's/\s//g' | sed -e 's/include//' | sed -e 's/\/\*\.conf\;//'`
  confdir=`readlink -f ${conflink}`
  if [[ $confdir != $conflink ]]; then
    workdir=`readlink -f ${conflink} | sed -e 's/\/conf$//'`
  fi
  inbounds_conf=$workdir/inbounds
  inbounds_logs=$workdir/logs/inbounds
}

# 初始化环境
init_inbounds() {
  curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install jq inotifywait
  mkdir -p $inbounds_conf
  mkdir -p $inbounds_logs
  update_inbounds
}

# 创建入站接口
create_inbound() {
  proxy_file="${inbounds_conf}/$2$(echo $1 | sed 's/\//::/g').inbound"
  echo -e "设置代理 $1 -> $2"
  echo -e "
location $1 {
    proxy_redirect      off;
    proxy_pass          http://127.0.0.1:$2;
    proxy_http_version  1.1;
    proxy_set_header    Upgrade \$http_upgrade;
    proxy_set_header    Connection upgrade;
    proxy_set_header    Host \$http_host;
    proxy_read_timeout  300s;
    proxy_set_header    X-Real-IP \$remote_addr;
    proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
}
" > $proxy_file
  echo -e "写入 $proxy_file 成功"
}

# 更新入站接口
update_inbounds() {
  if [[ ! -f $config ]]; then
    return
  fi
  rm -rf $inbounds_conf/*
  paths=`cat $config | jq -r ".inbounds" | jq -r ".[].streamSettings.wsSettings.path" | awk -v RS='' '{gsub("\n"," "); print}'`
  list=0
  for path in ${paths[@]}
  do
    if [[ $path != null ]]; then
      echo -e "`create_inbound $path $(cat $config | jq -r ".inbounds" | jq -r ".[$list].port")`"
    fi
    list=`expr $list + 1`
  done
  systemctl restart nginx
}

# 监听配置文件
monitor_inbounds() {
  times=`date +%s`
  inotifywait -mrq --format '%e' --event modify  $config | while read event
  do
    case $event in
    MODIFY)
      diff=$(expr $(date +%s) - $times)
      if [[ $diff -gt $step ]]; then
        update_inbounds
      fi
    ;;
    esac
    times=`date +%s`
  done
}

get_nginx_env
case "$1" in
--init)
  init_inbounds
;;
*)
  monitor_inbounds
;;
esac