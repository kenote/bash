#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh
source $(cd $(dirname $0);pwd)/disk/base.sh
source $(cd $(dirname $0);pwd)/disk/swap.sh

show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> 磁盘管理"
    echo "------------------------"
    echo "1. 查看磁盘信息"
    echo "2. 挂载磁盘分区"
    echo "3. 卸载磁盘分区"
    echo "4. 扩容磁盘分区"
    echo "------------------------"
    echo "5. 设置交换分区"
    echo "6. 删除交换分区"
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
    echo "磁盘信息"
    echo "------------------------"
    echo
    get_disk_list
    echo
    echo "分区信息"
    echo "------------------------"
    echo
    df -Th | grep -v -E "overlay|tmpfs|/dev/dm"
    echo
    echo "交换分区"
    echo "------------------------"
    echo
    get_swap_info
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    clear
    echo "挂载磁盘分区"
    echo "------------------------"
    echo
    get_disk_list "mount"
    echo
    if [[ ! ${#MOUNT_LIST[@]} -gt 0 ]]; then
      echo -e "- ${yellow}没有可挂载的磁盘${plain}"
      echo
      read -n1 -p "按任意键继续" key
      clear
      show_menu
      return
    fi
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "选择挂载磁盘: " name
    do
      goback $name "clear;show_menu"
      if [[ ! -n $name ]]; then
        show_menu "" 2 "请选择挂载磁盘"
        continue
      fi
      if !(echo ${MOUNT_LIST[@]} | grep -w -q "$name"); then
        show_menu "" 2 "挂载磁盘不存在或该磁盘已经挂载"
        continue
      fi
      break
    done
    mount_disk "$name" 2
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  3)
    clear
    echo "卸载磁盘分区"
    echo "------------------------"
    echo
    get_disk_list "remove"
    echo
    if [[ ! ${#REMOVE_LIST[@]} -gt 0 ]]; then
      echo -e "- ${yellow}没有可卸载的磁盘${plain}"
      echo
      read -n1 -p "按任意键继续" key
      clear
      show_menu
      return
    fi
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "选择卸载磁盘: " name
    do
      goback $name "clear;show_menu"
      if [[ ! -n $name ]]; then
        show_menu "" 3 "请选择卸载磁盘"
        continue
      fi
      if !(echo ${REMOVE_LIST[@]} | grep -w -q "$name"); then
        show_menu "" 3 "卸载磁盘不存在或该磁盘已经卸载"
        continue
      fi
      break
    done
    remove_disk "$name"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  4)
    clear
    echo "扩容磁盘分区"
    echo "------------------------"
    echo
    get_disk_list
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "选择扩磁盘: " name
    do
      goback $name "clear;show_menu"
      if [[ ! -n $name ]]; then
        show_menu "" 4 "请选择扩容磁盘"
        continue
      fi
      if !(echo ${ALL_DISKS[@]} | grep -w -q "$name"); then
        show_menu "" 4 "选择的磁盘不存在"
        continue
      fi
      break
    done
    expand_disk "$name"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  5)
    clear
    echo "设置交换分区"
    echo "------------------------"
    echo
    get_swap_info
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "交换分区大小(单位: Mb): " size
    do
      goback $sizesize "clear;show_menu"
      if [[ ! -n $size ]]; then
        show_menu "" 4 "请填写交换分区大小"
        continue
      fi
      if [[ ! -n $(echo "$size" | gawk '/^[1-9]{1}[0-9]+?/{print $0}') ]]; then
        show_menu "" 4 "请正确填写分区大小"
        continue
      fi
      break
    done
    set_swap $(echo "$size*1024" | bc)
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  6)
    clear
    echo "删除交换分区"
    echo "------------------------"
    echo
    get_swap_info
    echo
    if [[ ! -n $swapfile ]]; then
      read -n1 -p "按任意键继续" key
      clear
      show_menu
      return
    fi
    confirm "确定要删除交换分区吗?" "n"
    if [[ $? == 1 ]]; then
      clear
      show_menu
      return
    fi
    remove_swap
    echo
    get_swap_info
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