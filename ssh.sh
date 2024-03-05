#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh
source $(cd $(dirname $0);pwd)/ssh/init.sh
source $(cd $(dirname $0);pwd)/ssh/server.sh
source $(cd $(dirname $0);pwd)/ssh/task.sh

show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> 服务器管理"
    echo "------------------------"
    echo "1. 选择服务器"
    echo "2. 添加服务器"
    echo "3. 设置传输率"
    echo "4. 进程任务查看"
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
    echo -e "加载中...\n"
    if [[ ! -n $3 ]]; then
      server_list "$4" "$5" > ~/kenote_ssh/temp_server.log
    fi
    clear
    echo "选择服务器"
    echo "------------------------"
    echo -e "${green}1${plain}. 输入 ${yellow}?<name>${plain} 检索名称"
    echo -e "${green}2${plain}. 输入 ${yellow}online${plain} 查看状态"
    echo -e "${green}3${plain}. 输入 ${yellow}#2${plain} 刷新列表"
    echo -e "${green}4${plain}. 输入 ${yellow}#1${plain} 返回"
    echo
    cat ~/kenote_ssh/temp_server.log
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "输入ID: " name
    do
      goback $name "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $name ]]; then
        show_menu "" 1 "请输入ID"
        continue
      fi
      if [[ $name == 'online' ]]; then
        show_menu "" 1 "" $name
        break
      fi
      if [[ -n $(echo $name | gawk '/^(\?)[^/s]*/{print $0}') ]]; then
        show_menu "" 1 "" "" "$name"
        return
      fi
      if [[ ! -n $(cat ~/kenote_ssh/setting.json | jq -r ".servers[] | select(.id==\"$name\")") ]]; then
        show_menu "" 1 "ID不存在"
        continue
      fi
      break
    done
    echo
    clear
    server_options $name 1
    clear
    show_menu
  ;;
  2)
    clear
    sub_title="添加服务器\n------------------------"
    echo -e $sub_title
    while read -p "名称: " name
    do
      goback $name "clear;show_menu"
      if [[ ! -n $name ]]; then
        warning "名称不能为空" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$name" | gawk '/([a-zA-Z0-9_\-\.]+)$/{print $0}') ]]; then
        warning "名称请用英文字母数字下划线中划线组成" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n名称: $name"
    clear && echo -e $sub_title
    while read -p "服务器地址: " address
    do
      goback $address "clear;show_menu"
      if [[ ! -n $address ]]; then
        warning "服务器地址不能为空" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_ipadress "$address") && ! -n $(is_domain "$address") ]]; then
        warning "请填写正确的服务器地址，域名或IP" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n服务器地址: $address"
    clear && echo -e $sub_title
    while read -p "端口(22): " port
    do
      goback $port "clear;show_menu"
      if [[ ! -n $port ]]; then
        port=22
      fi
      if [[ ! -n $(is_port "$port") && -n $port ]]; then
        warning "请填写正确的端口" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n端口: $port"
    clear && echo -e $sub_title
    while read -p "用户名(root): " user
    do
      goback $user "clear;show_menu"
      if [[ ! -n $user ]]; then
        user="root"
      fi
      if [[ ! -n $(echo "$user" | gawk '/([a-zA-Z0-9_\-\.]+)$/{print $0}') && -n $user ]]; then
        warning "请填写正确的用户名" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n用户名: $user"
    clear && echo -e $sub_title
    echo
    create_server --name "$name" --address "$address" --port "$port" --user "$user"
    echo
    read  -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  3)
    clear
    KENOTE_RSYNC_BWLIMIT=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_RSYNC_BWLIMIT)
    sub_title="设置传输率(单位: kb) -- $KENOTE_RSYNC_BWLIMIT\n------------------------------"
    echo -e $sub_title
    while read -p "传输速度: " bwlimit
    do
      goback $bwlimit "clear;show_menu"
      if [[ ! -n $(echo "$bwlimit" | gawk '/^[1-9]{1}[0-9]{1,4}?$/{print $0}') && -n $bwlimit ]]; then
        warning "传输速度为 1 - 99999 数字" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n传输速度: $bwlimit"
    clear && echo -e $sub_title
    if [[ -n $bwlimit ]]; then
      curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --set-env KENOTE_RSYNC_BWLIMIT "$bwlimit"
    else
      curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --del-env KENOTE_RSYNC_BWLIMIT
    fi
    echo
    echo "- 设置完成"
    echo
    read  -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  4)
    clear
    echo "进程任务查询"
    echo "------------------------"
    echo -e "${green}1${plain}. 输入 ${yellow}#2${plain} 刷新列表"
    echo -e "${green}2${plain}. 输入 ${yellow}#1${plain} 返回"
    echo

    task_list
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "查询PID: " name
    do
      goback $name "clear;show_menu" "show_menu \"\" 4"
      if [[ ! -n $name ]]; then
        show_menu "" 4 "请输入查询的PID"
        continue
      fi
      if [[ ${#name} -lt 5 ]]; then
        show_menu "" 4 "至少输入5个字符"
        continue
      fi
      if [[ ! -n $(cat ~/kenote_ssh/setting.json | jq -r ".tasks[].name | scan(\".*$name.*\")") ]]; then
        show_menu "" 4 "查询的PID不存在"
        continue
      fi
      break
    done
    echo
    
    task_options "$(cat ~/kenote_ssh/setting.json | jq -r ".tasks[].name | scan(\".*$name.*\")" | sed -n 1p)" 4

    echo
    read  -n1 -p "按任意键继续" key
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

case $1 in
--del-task)
  del_task $2
;;
*)
  init_ssh
  clear
  show_menu
;;
esac