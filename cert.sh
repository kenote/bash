#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh
source $(cd $(dirname $0);pwd)/cert/acme.sh

show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> 证书管理"
    echo "------------------------"
    echo "1. ACME.SH信息"
    echo "2. 签发新证书"
    echo "3. 查看签发证书"
    echo "------------------------"
    echo "11. 安装ACME.SH"
    echo "12. 卸载ACME.SH"
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
    echo "ACME.SH信息"
    echo "------------------------"
    echo
    is_acme_env 0
    $KENOTE_ACMECTL --version
    echo
    $KENOTE_ACMECTL --info
    echo
    $KENOTE_ACMECTL --list
    echo
    echo "Crontab"
    echo "------------------------"
    crontab -l | grep "acme.sh" | grep ""
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    clear
    echo "签发新证书"
    echo "------------------------"
    echo -e "${green}1${plain}. 提前将域名解析到本机并可正常访问80端口"
    echo -e "${green}2${plain}. 输入 ${yellow}#1${plain} 返回"
    echo
    is_acme_env 0
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "请绑定一个域名: " domain
    do
      goback $domain "clear;show_menu"
      if [[ ! -n $domain ]]; then
        show_menu "" 2 "请填写域名"
        continue
      fi
      is_param_true "is_domain" "${domain[*]}"
      if [[ $? == 1 ]]; then
        show_menu "" 2 "绑定域名中存在格式错误"
        continue
      fi
      break
    done
    echo
    issue_cert_nginx "${domain[*]}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  3)
    clear
    echo "查看签发证书"
    echo "------------------------"
    echo
    is_acme_env 0
    $KENOTE_ACMECTL --list
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "输入域名: " name
    do
      goback $name "clear;show_menu" "show_menu \"\" 3"
      if [[ ! -n $name ]]; then
        show_menu "" 3 "请输入域名"
        continue
      fi
      if [[ ! -n $($KENOTE_ACMECTL --list | grep -E "^$name\s+") ]]; then
        show_menu "" 3 "域名证书不存在"
        continue
      fi
      break
    done
    echo
    clear
    cert_options $name 3
    clear
    show_menu
  ;;

  11)
    clear
    echo "安装ACME.SH"
    echo "------------------------"
    echo
    is_acme_env 1
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "请设置一个邮箱: " email
    do
      goback $email "clear;show_menu"
      if [[ ! -n $email ]]; then
        show_menu "" 11 "请填写邮箱地址"
        continue
      fi
      if [[ ! -n $(is_email "$email") ]]; then
        show_menu "" 11 "请填写正确的邮箱地址"
        continue
      fi
      break
    done
    install_acme "$email"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  12)
    clear
    echo "卸载ACME.SH"
    echo "------------------------"
    echo
    is_acme_env 0
    confirm "确定要执行卸载ACME.SH吗?" "n"
    if [[ $? == 1 ]]; then
      clear
      show_menu
      return
    fi
    remove_acme
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
