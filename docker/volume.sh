#! /bin/bash

volume_options() {
  clear
  echo "数据卷管理"
  echo "------------------------"
  echo
  docker volume ls
  echo
  echo "操作选项"
  echo "---------------------------------------------"
  echo "1. 创建数据卷         2. 查看数据卷"
  echo "3. 删除数据卷         4. 清理无用卷"
  echo "---------------------------------------------"
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
    sub_title="创建数据卷\n------------------------"
    echo -e $sub_title
    while read -p "数据卷名称: " name
    do
      goback $name "clear;volume_options"
      if [[ ! -n $name ]]; then
        warning "请输入数据卷名称！" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$name" | gawk '/^[a-zA-Z]{1}[0-9a-zA-Z\-]{3,19}$/{print $0}') ]]; then
        warning "数据卷名称格式错误！" "$sub_title"
        continue
      fi
      if [[ -n $(docker volume ls | awk '{if (NR>1){print $2}}' | grep -E "^$name$") ]]; then
        warning "数据卷名称已存在！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n数据卷名称: $name"
    clear && echo -e $sub_title
    echo
    if [[ -n $(docker volume create $name | grep -E "^$name$") ]]; then
      echo -e "- ${yellow}数据卷 $name 已创建成功${plain}"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    volume_options
  ;;
  2)
    clear
    sub_title="查看数据卷\n------------------------"
    echo -e $sub_title
    echo
    docker volume ls
    echo
    while read -p "数据卷名称: " name
    do
      goback $name "clear;volume_options"
      if [[ ! -n $name ]]; then
        warning "请输入数据卷名称！" "$sub_title" "docker volume ls"
        continue
      fi
      if [[ ! -n $(docker volume ls | awk '{if (NR>1){print $2}}' | grep -E "^$name$") ]]; then
        warning "数据卷名称不存在！" "$sub_title" "docker volume ls"
        continue
      fi
      break
    done
    sub_title="$sub_title\n数据卷名称: $name"
    clear && echo -e $sub_title
    echo
    docker volume inspect $name | jq -r '.[]'
    echo
    read -n1 -p "按任意键继续" key
    clear
    volume_options
  ;;
  3)
    clear
    sub_title="删除数据卷\n------------------------"
    echo -e $sub_title
    echo
    docker volume ls
    echo
    while read -p "数据卷名称: " name
    do
      goback $name "clear;volume_options"
      if [[ ! -n $name ]]; then
        warning "请输入数据卷名称！" "$sub_title" "docker volume ls"
        continue
      fi
      if [[ ! -n $(docker volume ls | awk '{if (NR>1){print $2}}' | grep -E "^$name$") ]]; then
        warning "数据卷名称不存在！" "$sub_title" "docker volume ls"
        continue
      fi
      break
    done
    sub_title="$sub_title\n数据卷名称: $name"
    clear && echo -e $sub_title
    echo
    if [[ -n $(docker volume rm $name | grep -E "^$name$") ]]; then
      echo -e "- ${yellow}数据卷 $name 已成功删除${plain}"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    volume_options
  ;;
  4)
    clear
    echo "清理无用卷"
    echo "------------------------"
    echo
    docker volume prune
    echo
    read -n1 -p "按任意键继续" key
    clear
    volume_options
  ;;
  0)
    clear
    show_menu
  ;;
  *)
    clear
    volume_options "请输入正确的数字"
  ;;
  esac
}