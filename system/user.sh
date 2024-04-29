#! /bin/bash

# 设置账号密码
set_user_pass() {
  # 如果不存在就创建
  if [[ ! -n $(getent passwd | grep ":/bin/bash" | grep -E "^$1:") ]]; then
    sudo useradd -m -s /bin/bash "$1"
  fi
  # 设置密码
  echo "$2" | passwd "$1" --stdin > /dev/null 2>&1
}

# 获取账号列表
get_user_list() {
  list=`getent passwd | grep ":/bin/bash" | grep -v "^root:"`
  printf "%-10s %-10s %-15s %-20s %-15s %-10s %-10s %-30s\n" "UID" "GID" "USERNAME" "HOME" "CREATE" "SUDO" "ACTIVE" "PASSWORD"
  echo "-----------------------------------------------------------------------------------------------------------------------------"
  for info in ${list[@]}
  do
    username=`echo "$info" | awk -F ":" '{print $1}'`
    uid=`echo "$info" | awk -F ":" '{print $3}'`
    gid=`echo "$info" | awk -F ":" '{print $4}'`
    home=`echo "$info" | awk -F ":" '{print $6}'`
    create_at=`passwd -S "$username" | awk -F " " '{print $3}'`
    password=`passwd -S "$username" | cut -d '(' -f2|cut -d ')' -f1`
    if [[ -n $(cat /etc/sudoers | grep -E "^$username\s+ALL=\(ALL(:ALL)?\)\s+ALL") ]]; then
      access="true"
    else
      access="false"
    fi
    if [[ -n $(whoami | grep -E "^$username$") ]]; then
      active="true"
    else
      active="false"
    fi
    printf "%-10s %-10s %-15s %-20s %-15s %-10s %-10s %-30s\n" "$uid" "$gid" "$username" "$home" "$create_at" "$access" "$active" "$password"
    unset username uid pid home create_at password access active
  done
  unset list info
}

# 账号管理选项
user_options() {
  clear
  echo "系统账号 -- $1"
  echo "------------------------"
  echo "创建日期: $(passwd -S "$1" | awk -F " " '{print $3}')"
  passwd -S "$1" | cut -d '(' -f2|cut -d ')' -f1
  
  echo
  echo "操作选项"
  echo "----------------------------------------------------------------"
  echo "1. 设置密码            2. 赋予SUDO权限         3. 取消SUDO权限"
  echo "4. 删除账号"
  echo "----------------------------------------------------------------"
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
    sub_title="设置系统账号 $1 的密码\n------------------------"
    echo -e $sub_title
    echo
    while read -p "新密码: " passwd
    do
      goback $passwd "clear;user_options $1 $2"
      if [[ ! -n $passwd ]]; then
        warning "请输入新密码" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_password "$passwd") ]]; then
        warning "新密码格式错误，支持长度为6-30个字符字母数字和特殊字符" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n新密码: $passwd"
    clear && echo -e $sub_title
    echo
    echo "$passwd" | passwd "$1" --stdin > /dev/null 2>&1
    echo -e "- ${yellow}账号 $1 的密码已更新${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    user_options $1 $2
  ;;
  2)
    clear
    echo "赋予系统账号 $1 SUDO权限"
    echo "------------------------"
    if [[ -n $(cat /etc/sudoers | grep -E "^$1\s+ALL=\(ALL(:ALL)?\)\s+ALL") ]]; then
      echo
      echo -e "- ${yellow}账号 $1 已经拥有SUDO权限${plain}"
      echo
      read -n1 -p "按任意键继续" key
      clear
      user_options $1 $2
      return
    fi
    confirm "确定要赋予账号SUDO权限吗?" "n"
    if [[ $? == 0 ]]; then
      echo
      echo "$1 ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
      echo
      echo -e "- ${yellow}已赋予账号 $1 SUDO权限${plain}"
      echo
      read -n1 -p "按任意键继续" key
    fi
    clear
    user_options $1 $2
  ;;
  3)
    clear
    echo "取消系统账号 $1 SUDO权限"
    echo "------------------------"
    if [[ ! -n $(cat /etc/sudoers | grep -E "^$1\s+ALL=\(ALL(:ALL)?\)\s+ALL") ]]; then
      echo
      echo -e "- ${yellow}账号 $1 未拥有SUDO权限${plain}"
      echo
      read -n1 -p "按任意键继续" key
      clear
      user_options $1 $2
      return
    fi
    confirm "确定要取消账号SUDO权限吗?" "n"
    if [[ $? == 0 ]]; then
      echo
      sudo sed -i "/^$1\sALL=(ALL:ALL)\sALL/d" /etc/sudoers
      echo -e "- ${yellow}已取消账号 $1 SUDO权限${plain}"
      echo
      read -n1 -p "按任意键继续" key
    fi
    clear
    user_options $1 $2
  ;;
  4)
    clear
    echo "删除系统账号 $1"
    echo "------------------------"
    confirm "确定要删除账号 $1 吗?" "n"
    if [[ $? == 0 ]]; then
      echo
      sudo userdel -r "$1"
      echo -e "- ${yellow}账号 $1 已删除${plain}"
      echo
      read -n1 -p "按任意键继续" key
      clear
      show_menu "" $2
    else
      clear
      user_options $1 $2
    fi
  ;;
  0)
    clear
    show_menu "" $2
  ;;
  *)
    clear
    user_options $1 $2 "请输入正确的数字"
  ;;
  esac
  unset sub_choice sub_title
}