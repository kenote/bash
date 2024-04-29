#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh
source $(cd $(dirname $0);pwd)/system/user.sh

show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> 系统账号管理"
    echo "------------------------"
    echo "1. 创建系统账号"
    echo "2. 查看系统账号"
    echo "3. 修改ROOT密码"
    echo "4. 开启ROOT登录"
    echo "5. 关闭ROOT登录"
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
    sub_title="创建系统账号\n------------------------"
    echo -e $sub_title
    while read -p "账号名称: " username
    do
      goback $username "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $username ]]; then
        warning "请输入账号名称" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_username "$username") ]]; then
        warning "账号名称格式错误，支持长度为4-20个字符的字母数字" "$sub_title"
        continue
      fi
      if [[ -n $(getent passwd | grep -v ":/bin/bash" | grep -E "^$username:") && $username == 'root' ]]; then
        warning "不能使用系统内置账号名" "$sub_title"
        continue
      fi
      if [[ -n $(getent passwd | grep ":/bin/bash" | grep -v "^root:" | grep -E "^$username\:") ]]; then
        warning "输入的账号名称已存在" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n账号名称: $username"
    clear && echo -e $sub_title
    while read -p "登录密码: " password
    do
      goback $password "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $password ]]; then
        warning "请输入登录密码" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_password "$password") ]]; then
        warning "密码格式错误，支持长度为6-30个字符字母数字和特殊字符" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n登录密码: $password"
    clear && echo -e $sub_title
    echo
    set_user_pass "$username" "$password"
    echo -e "- ${yellow}系统账号 $username 已创建成功${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    clear
    echo "查看系统账号"
    echo "------------------------"
    echo
    get_user_list
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "输入账号: " name
    do
      goback $name "clear;show_menu" "show_menu \"\" 2"
      if [[ ! -n $name ]]; then
        show_menu "" 2 "请输入账号"
        continue
      fi
      if [[ ! -n $(getent passwd | grep ":/bin/bash" | grep -v "^root:" | grep -E "^$name\:") ]]; then
        show_menu "" 2 "输入的账号不存在"
        continue
      fi
      if [[ -n $(whoami | grep -E "^$name$") ]]; then
        show_menu "" 2 "不能选择当前正在使用的账号"
        continue
      fi
      break
    done
    echo
    user_options "$name" 2
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  3)
    clear
    sub_title="修改ROOT密码\n------------------------"
    echo -e $sub_title
    while read -p "ROOT密码: " password
    do
      goback $password "clear;show_menu" "show_menu \"\" 3"
      if [[ ! -n $password ]]; then
        warning "请输入ROOT密码" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_password "$password") ]]; then
        warning "密码格式错误，支持长度为6-30个字符字母数字和特殊字符" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\nROOT密码: $password"
    clear && echo -e $sub_title
    echo
    echo "$passwd" | passwd "root" --stdin > /dev/null 2>&1
    echo -e "- ${yellow}ROOT密码已修改${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  4)
    clear
    sub_title="开启ROOT登录\n------------------------"
    echo -e $sub_title
    while read -p "ROOT密码: " password
    do
      goback $password "clear;show_menu" "show_menu \"\" 4"
      if [[ ! -n $password ]]; then
        warning "请输入ROOT密码" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_password "$password") ]]; then
        warning "密码格式错误，支持长度为6-30个字符字母数字和特殊字符" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\nROOT密码: $password"
    clear && echo -e $sub_title
    echo
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    if (command -v systemctl &> /dev/null); then
      systemctl restart sshd
    else
      service sshd restart
    fi
    echo -e "- ${yellow}ROOT登录已开启${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  5)
    clear
    sub_title="关闭ROOT登录\n------------------------"
    sub_title="$sub_title\n- ${yellow}需要先创建新的登录账号${plain}\n"
    echo -e $sub_title
    while read -p "新账号名称: " username
    do
      goback $username "clear;show_menu" "show_menu \"\" 5"
      if [[ ! -n $username ]]; then
        warning "请输入新账号名称" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_username "$username") ]]; then
        warning "账号名称格式错误，支持长度为4-20个字符的字母数字" "$sub_title"
        continue
      fi
      if [[ -n $(getent passwd | grep -v ":/bin/bash" | grep -E "^$username:") && $username == 'root' ]]; then
        warning "不能使用系统内置账号名" "$sub_title"
        continue
      fi
      if [[ -n $(getent passwd | grep ":/bin/bash" | grep -v "^root:" | grep -E "^$username\:") ]]; then
        warning "输入的账号名称已存在" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n新账号名称: $username"
    clear && echo -e $sub_title
    while read -p "登录密码: " password
    do
      goback $password "clear;show_menu" "show_menu \"\" 5"
      if [[ ! -n $password ]]; then
        warning "请输入登录密码" "$sub_title"
        continue
      fi
      if [[ ! -n $(is_password "$password") ]]; then
        warning "密码格式错误，支持长度为6-30个字符字母数字和特殊字符" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n登录密码: $password"
    clear && echo -e $sub_title
    echo
    set_user_pass "$username" "$password"
    echo "$1 ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers
    echo
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
    if (command -v systemctl &> /dev/null); then
      systemctl restart sshd
    else
      service sshd restart
    fi
    echo -e "- ${yellow}ROOT登录已关闭${plain}"
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