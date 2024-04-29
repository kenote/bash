#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh
source $(cd $(dirname $0);pwd)/system/base.sh

show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> 系统设置"
    echo "------------------------"
    echo "1. 设置主机名"
    echo "2. 设置系统时区"
    echo "3. 设置系统时间"
    echo "4. 设置时钟同步"
    if (command -v getenforce &> /dev/null); then
      echo "------------------------"
      echo "5. 更改SELINX"
    fi
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
    sub_title="设置主机名\n------------------------"
    echo -e $sub_title
    while read -p "主机名: " name
    do
      goback $name "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $name ]]; then
        warning "请输入主机名" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$name" | gawk '/^[a-zA-Z]{1}[a-zA-Z0-9\-\_|.]{2,24}$/{print $0}') ]]; then
        warning "主机名不合规，至少3个字符英语字母和数字组成且必须以英语字母开头" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n主机名: $name"
    clear && echo -e $sub_title
    echo
    set_hostname "$name"
    sleep 3
    echo -e "- ${yellow}主机名已变更, 需要重启终端才能生效${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    clear
    set_timezone "设置系统时区\n------------------------"
    if [[ $? == 0 ]]; then
      echo
      echo -e "- ${yellow}系统时区已经切换至 -- $(timedatectl | grep "Time zone" | sed -E 's/^(\s+)(Time\szone)\:\s//')${plain}"
      echo
      read -n1 -p "按任意键继续" key
    fi
    clear
    show_menu
  ;;
  3)
    clear
    sub_title="设置系统时间\n------------------------"
    echo -e $sub_title
    while read -p "指定时间(YYYY-MM-DD HH:mm:ss): " datetime
    do
      goback $datetime "clear;show_menu" "show_menu \"\" 3"
      if [[ ! -n $datetime ]]; then
        warning "请输入指定时间" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_datetime "$datetime") ]]; then
        warning "指定时间格式不正确" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n指定时间(YYYY-MM-DD HH:mm:ss): : $datetime"
    clear && echo -e $sub_title
    echo
    # 先停止同步时间
    if (command -v chronyd &> /dev/null); then
      systemctl stop chronyd
    fi
    # 写入系统时钟
    date -s "$datetime"
    clock -w
    echo
    echo -e "- ${yellow}系统时间已更新 -- $(date)${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  4)
    clear
    chrony_options
    clear
    show_menu
  ;;
  5)
    clear
    set_selinux "更改SELINUX\n------------------------"
    if [[ $? == 0 ]]; then
      echo
      if [[ -n $(cat /etc/selinux/config | grep -E "^SELINUX=" | grep -i "$(getenforce)") ]]; then
        echo -e "- ${yellow}SELINUX 已更改为 $(getenforce)${plain}"
      else
        echo -e "- ${yellow}SELINUX 已更改为 $(cat /etc/selinux/config | grep -E "^SELINUX=" | sed -e 's/^SELINUX=//' | sed -e "s/\b\(.\)/\u\1/g")，需要重启系统才能生效${plain}"
      fi
      echo
      read -n1 -p "按任意键继续" key
    fi
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

init_sys
clear
show_menu