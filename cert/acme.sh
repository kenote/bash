#! /bin/bash

# 安装 acme
install_acme() {
  cd $HOME
  curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install socat
  if (curl --connect-timeout 5 https://www.google.com -s --head | head -n 1 | grep "HTTP/[123].." &> /dev/null); then
    curl https://get.acme.sh | sh -s email=$1
  else
    git clone https://gitee.com/neilpang/acme.sh.git
    cd ./acme.sh
    ./acme.sh --install -m $1
  fi
  if [[ ! -f $KENOTE_ACMECTL ]]; then
    echo
    echo -e "${yellow}未能成功安装ACME.SH${plain}"
    return
  fi
  # 关闭自动更新
  $KENOTE_ACMECTL --upgrade --auto-upgrade 0
  # 设置默认证书
  $KENOTE_ACMECTL --set-default-ca --server letsencrypt
  echo
  echo -e "${green}安装ACME.SH完成${plain}"
}

# 删除 acme
remove_acme() {
  $KENOTE_ACMECTL --uninstall
  rm -rf "/root/.acme.sh/"
  echo
  echo -e "${green}卸载ACME.SH完成${plain}"
}

# 判断 acme 环境
is_acme_env() {
  if [[ ! -f $KENOTE_ACMECTL && $1 == 0 ]]; then
    echo -e "- ${yellow}ACME.SH 未安装${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
    return
  fi
  if [[ -f $KENOTE_ACMECTL && $1 == 1 ]]; then
    echo -e "- ${yellow}ACME.SH 已安装${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
    return
  fi
}

# 签发证书
issue_cert_nginx() {
  $KENOTE_ACMECTL --issue $(to_array_param "--domain" "$1") --nginx --force
}

# 安装证书
install_cert_nginx() {
  fullchainFile="$KENOTE_SSL_PATH/$1/cert.crt"
  keyFile="$KENOTE_SSL_PATH/$1/private.key"
  mkdir -p $KENOTE_SSL_PATH/$1
  $KENOTE_ACMECTL --install-cert --domain $1 --fullchain-file $fullchainFile --key-file $keyFile --reloadcmd "systemctl restart nginx"
  unset fullchainFile keyFile
}

# 撤销证书
revoke_cert() {
  $KENOTE_ACMECTL --revoke --domain $1
}

# 删除证书
remove_cert() {
  $KENOTE_ACMECTL --remove --domain $1
  rm -rf $(find $(dirname $KENOTE_ACMECTL) -type d -name "$1*")
}

# 转jks证书
cert2jks() {
  curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install keytool
  target=`find $(dirname $KENOTE_ACMECTL) -type d -name "$1*"`
  if [[ ! -n $target ]]; then
    echo -e "- ${yellow}没有找到相关证书${plain}"
    return
  fi
  pass=`echo $RANDOM | sha512sum | head -c 8`
  mkdir -p $KENOTE_SSL_PATH/$1
  rm -rf $KENOTE_SSL_PATH/$1/keystore.*
  openssl pkcs12 -export -in $target/fullchain.cer -inkey $target/$1.key -out $KENOTE_SSL_PATH/$1/keystore.p12 -name "$1" -password pass:$pass
  keytool -importkeystore -deststorepass "$pass" -destkeypass "$pass" -destkeystore $KENOTE_SSL_PATH/$1/keystore.jks -srckeystore $KENOTE_SSL_PATH/$1/keystore.p12 -srcstoretype pkcs12 -srcstorepass "$pass" -alias "$1"
  keytool -importkeystore -srckeystore $KENOTE_SSL_PATH/$1/keystore.jks -destkeystore $KENOTE_SSL_PATH/$1/keystore.jks -deststoretype pkcs12 -srcstorepass "$pass"
  echo "$pass" > $KENOTE_SSL_PATH/$1/jks-password.txt
  echo
  echo "- JKS已生成，存放在 $KENOTE_SSL_PATH/$1 目录下"
  echo
  echo "可通过以下指令查看JKS信息"
  echo "------------------------------------------------------------------------------------------"
  echo "keytool -list -v -keystore $KENOTE_SSL_PATH/$1/keystore.jks -storepass \"$(cat $KENOTE_SSL_PATH/$1/jks-password.txt)\""
  echo "------------------------------------------------------------------------------------------"
  echo
}

# 签发证书选项
cert_options() {
  clear
  info=`$KENOTE_ACMECTL --list | grep -E "^$1\s+"`
  echo "域名证书 -- $(echo $info | awk -F " " '{print $1}')"
  echo "------------------------"
  echo "密钥长度: $(echo $info | awk -F " " '{print $2}')"
  echo "服务商: $(echo $info | awk -F " " '{print $4}')"
  echo "签发时间: $(echo $info | awk -F " " '{print $5}')"
  
  echo
  echo
  echo "操作选项"
  echo "---------------------------------------------"
  echo "1. 安装证书           2. 生成JKS"
  echo "3. 撤销证书           4. 删除证书"
  echo "---------------------------------------------"
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
    echo "安装证书 -- $(echo $info | awk -F " " '{print $1}')"
    echo "------------------------"
    confirm "确定要安装该证书吗?" "n"
    if [[ $? == 0 ]]; then
      echo
      install_cert_nginx "$(echo $info | awk -F " " '{print $1}')"
      echo
      read -n1 -p "按任意键继续" key
    fi
    clear
    cert_options $1 $2
  ;;
  2)
    clear
    echo "生成JKS -- $(echo $info | awk -F " " '{print $1}')"
    echo "------------------------"
    confirm "确定要生成JKS证书吗?" "n"
    if [[ $? == 0 ]]; then
      echo
      cert2jks "$(echo $info | awk -F " " '{print $1}')"
      echo
      read -n1 -p "按任意键继续" key
    fi
    clear
    cert_options $1 $2
  ;;
  3)
    clear
    echo "撤销证书 -- $(echo $info | awk -F " " '{print $1}')"
    echo "------------------------"
    confirm "确定要撤销该证书吗?" "n"
    if [[ $? == 0 ]]; then
      echo
      revoke_cert "$(echo $info | awk -F " " '{print $1}')"
      echo
      read -n1 -p "按任意键继续" key
    fi
    clear
    cert_options $1 $2
  ;;
  4)
    clear
    echo "删除证书 -- $(echo $info | awk -F " " '{print $1}')"
    echo "------------------------"
    confirm "确定要删除该证书吗?" "n"
    if [[ $? == 0 ]]; then
      echo
      revoke_cert "$(echo $info | awk -F " " '{print $1}')"
      echo
      read -n1 -p "按任意键继续" key
      clear
      show_menu "" $2
    else
      clear
      cert_options $1 $2
    fi
  ;;
  0)
    clear
    show_menu "" $2
  ;;
  *)
    clear
    cert_options $1 $2 "请输入正确的数字"
  ;;
  esac
  unset info sub_choice
}