#! /bin/bash

# 初始化组件
init_sys() {
  if !(command -v chronyd &> /dev/null); then
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install chronyd
    systemctl enable chronyd
    systemctl start chronyd
  fi
}

# 设置主机名
set_hostname() {
  sed -i "s/$(echo $(hostname) $(hostname -f))/$(echo $1 $(echo $1 | awk -F '.' '{print $1}'))/g" /etc/hosts
  echo $1 | awk -F '.' '{print $1}' > /etc/hostname
  hostname -F /etc/hostname
}

# 设置系统时区
set_timezone() {

  echo -e "$1"
  echo "当前系统时区: $(timedatectl | grep "Time zone" | sed -E 's/^(\s+)(Time\szone)\:\s//')"
  echo "当前系统时间: $(date +"%Y-%m-%d %H:%M:%S")"
  echo
  echo "时区切换"
  echo "亚洲-------------------------------------"
  echo "1. 中国上海          2. 中国香港"
  echo "3. 日本东京          4. 韩国首尔"
  echo "5. 新加坡            6. 印度加尔各答"
  echo "7. 阿联酋迪拜        8. 澳大利亚悉尼"
  echo "欧洲--------------------------------------"
  echo "11. 英国伦敦         12. 法国巴黎"
  echo "13. 德国柏林         14. 荷兰阿姆斯特丹"
  echo "15. 瑞士苏黎世       16. 西班牙马德里"
  echo "17. 俄罗斯莫斯科     18. 乌克兰基辅"
  echo "19. 波兰华沙         20. 芬兰赫尔辛基"
  echo "美洲--------------------------------------"
  echo "31. 美国洛杉矶       32. 美国纽约"
  echo "33. 加拿大温哥华     34. 墨西哥城"
  echo "35. 巴西圣保罗       36. 阿根廷布宜诺斯艾利斯"
  echo "------------------------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  echo
  if [[ -n $2 ]]; then
    echo -e "${red}$2${plain}"
    echo
  fi
  read -p "请输入选择: " sub_choice

  case $sub_choice in
  1) timedatectl set-timezone Asia/Shanghai ;;
  2) timedatectl set-timezone Asia/Hong_Kong ;;
  3) timedatectl set-timezone Asia/Tokyo ;;
  4) timedatectl set-timezone Asia/Seoul ;;
  5) timedatectl set-timezone Asia/Singapore ;;
  6) timedatectl set-timezone Asia/Kolkata ;;
  7) timedatectl set-timezone Asia/Dubai ;;
  8) timedatectl set-timezone Australia/Sydney ;;
  11) timedatectl set-timezone Europe/London ;;
  12) timedatectl set-timezone Europe/Paris ;;
  13) timedatectl set-timezone Europe/Berlin ;;
  14) timedatectl set-timezone Europe/Amsterdam ;;
  15) timedatectl set-timezone Europe/Zurich ;;
  16) timedatectl set-timezone Europe/Madrid ;;
  17) timedatectl set-timezone Europe/Moscow ;;
  18) timedatectl set-timezone Europe/Kyiv ;;
  19) timedatectl set-timezone Europe/Warsaw ;;
  20) timedatectl set-timezone Europe/Helsinki ;;
  31) timedatectl set-timezone America/Los_Angeles ;;
  32) timedatectl set-timezone America/New_York ;;
  33) timedatectl set-timezone America/Vancouver ;;
  34) timedatectl set-timezone America/Mexico_City ;;
  35) timedatectl set-timezone America/Sao_Paulo ;;
  36) timedatectl set-timezone America/Argentina/Buenos_Aires ;;
  0) return 1 ;;
  *)
    clear
    set_timezone "$1" "请输入正确的数字"
  ;;
  esac
  return 0
}

# 设置时钟同步
chrony_options() {
  echo "> 系统设置 > 设置时钟同步"
  echo "------------------------"
  echo "1. 查看NTP信息"
  echo "2. 添加NTP服务器"
  echo "3. 删除NTP服务器"
  echo "------------------------"
  echo "11. 启动时钟同步"
  echo "12. 停止时钟同步"
  echo "13. 重启时钟同步"
  echo "------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  echo
  if [[ -n $1 ]]; then
    echo -e "${red}$1${plain}"
    echo
  fi
  read -p "请输入选择: " sub_choice

  case $sub_choice in
  1)
    clear
    echo "查看NTP信息"
    echo "------------------------"
    echo "-- $(systemctl status chronyd | grep "active" | cut -d '(' -f2|cut -d ')' -f1) --"
    echo
    if [[ $(systemctl status chronyd | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'running' ]]; then
      chronyc tracking
      echo
      chronyc sourcestats
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    chrony_options
  ;;
  2)
    clear
    sub_title="添加NTP服务器\n------------------------"
    echo -e $sub_title
    while read -p "服务器地址: " address
    do
      goback $address "clear;chrony_options"
      if [[ ! -n $address ]]; then
        warning "请输入服务器地址！" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_domain "$address") ]]; then
        warning "服务器地址格式错误！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n服务器地址: $address"
    clear && echo -e $sub_title
    echo
    chronyc add server "$address"
    echo
    read -n1 -p "按任意键继续" key
    clear
    chrony_options
  ;;
  3)
    clear
    sub_title="删除NTP服务器\n------------------------"
    echo -e $sub_title
    echo
    chronyc sourcestats
    echo
    while read -p "服务器地址: " address
    do
      goback $address "clear;chrony_options"
      if [[ ! -n $address ]]; then
        warning "请输入服务器地址！" "$sub_title" "chronyc sourcestats"
        continue
      fi
      if [[ ! -n $(chronyc sourcestats | grep -E "^$address\s+") ]]; then
        warning "服务器地址不存在！" "$sub_title" "chronyc sourcestats"
        continue
      fi
      break
    done
    sub_title="$sub_title\n服务器地址: $address"
    clear && echo -e $sub_title
    echo
    chronyc delete "$address"
    echo
    read -n1 -p "按任意键继续" key
    clear
    chrony_options
  ;;
  11)
    clear
    if [[ $(systemctl status chronyd | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'running' ]]; then
      systemctl restart chronyd
    else
      systemctl start chronyd
    fi
    systemctl status chronyd
    echo
    read -n1 -p "按任意键继续" key
    clear
    chrony_options
  ;;
  12)
    clear
    if [[ $(systemctl status chronyd | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'running' ]]; then
      systemctl stop chronyd
    fi
    systemctl status chronyd
    echo
    read -n1 -p "按任意键继续" key
    clear
    chrony_options
  ;;
  13)
    clear
    systemctl restart chronyd
    systemctl status chronyd
    echo
    read -n1 -p "按任意键继续" key
    clear
    chrony_options
  ;;
  0)
    clear
    show_menu
  ;;
  *)
    clear
    chrony_options "请输入正确的数字"
  ;;
  esac
}

# 设置 SELINUX 模式
set_selinux() {
  SELINUX_TYPE=$(get_selinux)
  echo -e "$1"
  echo "当前模式: $(get_selinux name)"
  echo
  echo "1. 强制模式"
  echo "2. 宽容模式"
  echo "3. 禁用"
  echo "------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  echo
  if [[ -n $2 ]]; then
    echo -e "${red}$2${plain}"
    echo
  fi
  read -p "请输入选择: " sub_choice

  case $sub_choice in
  1)
    sed -i 's/^#\?SELINUX\=.*/SELINUX=enforcing/g' /etc/selinux/config
    if [[ -n $(echo "Enforcing|Permissive" | grep "$SELINUX_TYPE") ]]; then
      setenforce 1
    fi
  ;;
  2)
    sed -i 's/^#\?SELINUX\=.*/SELINUX=permissive/g' /etc/selinux/config
    if [[ -n $(echo "Enforcing|Permissive" | grep "$SELINUX_TYPE") ]]; then
      setenforce 0
    fi
  ;;
  3)
    sed -i 's/^#\?SELINUX\=.*/SELINUX=disabled/g' /etc/selinux/config
  ;;
  0) return 1 ;;
  *)
    clear
    set_selinux "$1" "请输入正确的数字"
  ;;
  esac
  return 0
}

# 获取 SELINUX 模式
get_selinux() {
  if [[ $1 == 'name' ]]; then
    case $(getenforce | tr A-Z a-z) in
    enforcing)
      echo "强制模式"
    ;;
    permissive)
      echo "宽容模式"
    ;;
    disabled)
      echo "禁用"
    ;;
    esac
  else
    getenforce
  fi
}