#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh
source $(cd $(dirname $0);pwd)/system/iptables.sh

show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> IPTABLES防火墙"
    echo "------------------------"
    echo "1. 放行指定端口"
    echo "2. 拒绝指定端口"
    echo "3. 放行指定IP(白名单)"
    echo "4. 禁止指定IP(黑名单)"
    echo "5. 删除指定规则"
    echo "------------------------"
    echo "11. 启动服务"
    echo "12. 停止服务"
    echo "13. 重启服务"
    echo "14. 查看端口信息"
    echo "15. 更新策略配置"
    echo "------------------------"
    echo "00. 安装IPTABLES"
    echo "99. 卸载IPTABLES"
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
    sub_title="放行指定端口\n------------------------"
    echo -e $sub_title
    while read -p "端口: " port
    do
      goback $port "clear;show_menu" 
      if [[ ! -n $port ]]; then
        warning "请输入端口" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$port" | gawk '/^[1-9]{1}[0-9]{1,5}(\-[1-9]{1}[0-9]{1,5})?(\,[1-9]{1}[0-9]{1,5}(\-[1-9]{1}[0-9]{1,5})?)?+(\/(tcp|ucp|icmp|all))?$/{print $0}') ]]; then
        warning "端口格式错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n端口: $port"
    clear && echo -e $sub_title
    while read -p "指定范围: " ips
    do
      goback $ips "clear;show_menu"
      if [[ -n $ips ]]; then
        is_param_true "is_ip" "${ips[*]}"
        if [[ $? == 1 ]]; then
          warning "IP地址格式存在错误" "$sub_title"
          continue
        fi
      fi
      break
    done
    sub_title="$sub_title\n指定范围: $ips"
    clear && echo -e $sub_title
    echo
    if [[ -n $ips ]]; then
      for ip in ${ips[*]}; do
        set_input_port "$port" "ACCEPT" "$ip"
      done
    else
      set_input_port "$port" "ACCEPT"
    fi
    get_rules_list
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    clear
    sub_title="拒绝指定端口\n------------------------"
    echo -e $sub_title
    while read -p "端口: " port
    do
      goback $port "clear;show_menu" 
      if [[ ! -n $port ]]; then
        warning "请输入端口" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$port" | gawk '/^[1-9]{1}[0-9]{1,5}(\-[1-9]{1}[0-9]{1,5})?(\,[1-9]{1}[0-9]{1,5}(\-[1-9]{1}[0-9]{1,5})?)?+(\/(tcp|ucp|icmp|all))?$/{print $0}') ]]; then
        warning "端口格式错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n端口: $port"
    clear && echo -e $sub_title
    while read -p "指定范围: " ips
    do
      goback $ips "clear;show_menu"
      if [[ -n $ips ]]; then
        is_param_true "is_ip" "${ips[*]}"
        if [[ $? == 1 ]]; then
          warning "IP地址格式存在错误" "$sub_title"
          continue
        fi
      fi
      break
    done
    sub_title="$sub_title\n指定范围: $ips"
    clear && echo -e $sub_title
    echo
    if [[ -n $ips ]]; then
      for ip in ${ips[*]}; do
        set_input_port "$port" "DROP" "$ip"
      done
    else
      set_input_port "$port" "DROP"
    fi
    get_rules_list
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  3)
    ipset_opts "白名单" "whitelist"
  ;;
  4)
    ipset_opts "黑名单" "blacklist"
  ;;
  5)
    clear
    echo "删除指定规则"
    echo "------------------------"
    echo
    get_rules_list
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "输入PID: " pid
    do
      goback $pid "clear;show_menu" "show_menu \"\" 6"
      if [[ ! -n $pid ]]; then
        show_menu "" 6 "请输入PID"
        continue
      fi
      break
    done
    ssh_port=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --info ssh_port)
    ssh_port_pid=$(sed -nE "/$(echo "dport $ssh_port")/=" $RULES_FILE | cut -d ":" -f 1)
    echo
    eval $(echo "del_rules ${pid[*]}" | sed -E "s/ $ssh_port_pid//g")
    unset ssh_port ssh_port_pid
    clear
    echo "删除指定规则"
    echo "------------------------"
    echo
    get_rules_list
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  11)
    clear
    is_iptables_env
    if [[ $(systemctl status iptables | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'exited' ]]; then
      systemctl restart iptables
    else
      systemctl start iptables
    fi
    systemctl status iptables
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  12)
    clear
    is_iptables_env
    if [[ $(systemctl status iptables | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'exited' ]]; then
      systemctl stop iptables
    fi
    systemctl status iptables
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  13)
    clear
    is_iptables_env
    systemctl restart iptables
    systemctl status iptables
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  14)
    clear
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --info ports
    read -n1  -p "按任意键继续" key
    clear
    show_menu
  ;;
  15)
    clear
    is_iptables_env
    echo "更新策略配置"
    echo "------------------------"
    echo
    get_rules_list
    echo
    confirm "确定要更新策略配置吗?" "n"
    if [[ $? == 0 ]]; then
      update_rules
      echo
      echo -e "- ${green}策略配置已更新${plain}"
      echo
    else
      clear
      show_menu
      return
    fi
    read -n1  -p "按任意键继续" key
    clear
    show_menu
  ;;
  00)
    clear
    if !(systemctl list-units | grep -Eq "(iptables|netfilter)"); then
      echo
      install_iptables
    fi
    echo
    echo -e "- ${green}iptables 初始化完成${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  99)
    clear
    if (systemctl list-units | grep -Eq "(iptables|netfilter)"); then
      echo
      confirm "确定要卸载 iptables 吗?" "n"
      if [[ $? == 0 ]]; then
        remove_iptables
        echo
        echo -e "- ${green}iptables 卸载完成${plain}"
      else
        clear
        show_menu
        return
      fi
    else
      echo
      echo -e "- ${yellow}iptables 尚未安装${plain}"
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