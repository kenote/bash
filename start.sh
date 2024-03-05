#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh

# 主菜单
show_menu() {
  if (uname -s | grep -i -q "darwin"); then
    mac_menu $1
  else
    linux_menu $1
  fi
}

# macos菜单
mac_menu() {
  show_title
  echo "------------------------"
  echo "1. 系统信息"
  echo "2. 进程监控"
  echo "3. 服务器管理 >"
  echo "------------------------"
  echo "00. 脚本更新"
  echo "------------------------"
  echo "0. 退出脚本"
  echo "------------------------"
  echo
  if [[ -n $1 ]]; then
    echo -e "${red}$1${plain}"
    echo
  fi
  read -p "请输入选择: " choice 

  case $choice in
  1)
    clear
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --info
    read -n1  -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install btop
    btop --utf-force
    clear
    show_menu
  ;;
  3)
    run_script ssh.sh
  ;;
  00)
    rm -rf ~/kenote/*
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --init
    ~/kenote/start.sh
  ;;
  0)
    clear
    exit 0
  ;;
  *)
    clear
    show_menu "请输入正确的数字"
  ;;
  esac
}

# linux菜单
linux_menu() {
  show_title
  echo "------------------------"
  echo "1. 系统信息"
  echo "2. 进程监控"
  echo "3. 磁盘管理 >"
  echo "4. 证书管理 >"
  echo "5. 探针测试 >"
  echo "6. 用户管理 >"
  echo "------------------------"
  echo "11. Docker管理 >"
  echo "12. Nginx管理 >"
  echo "13. 服务器管理 >"
  echo "14. 防火墙 >"
  echo "15. 应用中心 >"
  echo "------------------------"
  echo "00. 脚本更新"
  echo "------------------------"
  echo "0. 退出脚本"
  echo "------------------------"
  echo
  if [[ -n $1 ]]; then
    echo -e "${red}$1${plain}"
    echo
  fi
  read -p "请输入选择: " choice 

  case $choice in
  1)
    clear
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --info
    read -n1  -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    if !(command -v btop &> /dev/null); then
      install_btop
    fi
    btop --utf-force
    clear
    show_menu
  ;;
  00)
    rm -rf ~/kenote/*
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --init
    ~/kenote/start.sh
  ;;
  0)
    clear
    exit 0
  ;;
  *)
    clear
    show_menu "请输入正确的数字"
  ;;
  esac
}

clear
show_menu