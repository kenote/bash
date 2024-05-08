#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh

show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> 定时任务管理"
    echo "------------------------"
    echo
    crontab -l
    echo
    echo "1. 自定义任务"
    echo "2. 每日任务"
    echo "3. 删除任务"
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
    sub_title="自定义任务\n------------------------"
    echo -e $sub_title
    while read -p "需要执行的命令: " newquest
    do
      goback $newquest "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $newquest ]]; then
        warning "请输入需要执行的命令" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n需要执行的命令: $newquest"
    clear && echo -e $sub_title
    while read -p "执行时间点(分钟, 0-59): " minute
    do
      goback $minute "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $(echo "$minute" | gawk '/^(\*)(\/[1-9]([0-9]{1,2})?)?$|^([0-9]|[1-5][0-9])([\,]([0-9]|[1-5][0-9]))?$/{print $0}') && -n $minute ]]; then
        warning "执行时间点(分钟)格式错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n执行时间点(分钟, 0-59): $minute"
    clear && echo -e $sub_title
    while read -p "执行时间点(小时, 0-23): " hour
    do
      goback $hour "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $(echo "$hour" | gawk '/^(\*)(\/[1-9]([0-9]{1,2})?)?$|^([0-9]|[1][0-9]|[2][0-3])([\-\,]{1}([0-9]|[1][0-9]|[2][0-3]))?(\/[1-9]([0-9]{1,2})?)?$/{print $0}') && -n $hour ]]; then
        warning "执行时间点(小时)格式错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n执行时间点(小时, 0-23): $hour"
    clear && echo -e $sub_title
    while read -p "执行时间点(日, 1-31): " day
    do
      goback $day "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $(echo "$day" | gawk '/^(\*)(\/[1-9]([0-9]{1,2})?)?$|^([1-9]|[1-2][0-9]|3[0-1])([\-\,]{1}([1-9]|[1-2][0-9]|3[0-1]))?(\/[1-9]([0-9]{1,2})?)?$/{print $0}') && -n $day ]]; then
        warning "执行时间点(日)格式错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n执行时间点(日, 1-31): $day"
    clear && echo -e $sub_title
    while read -p "执行时间点(月, 1-12): " month
    do
      goback $month "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $(echo "$month" | gawk '/^(\*)(\/[1-9]([0-9]{1,2})?)?$|^([1-9]|[1][0-2])([\-\,]{1}([1-9]|[1][0-2]))?(\/[1-9]([0-9]{1,2})?)?$/{print $0}') && -n $month ]]; then
        warning "执行时间点(月)格式错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n执行时间点(月, 1-12): $month"
    clear && echo -e $sub_title
    while read -p "执行时间点(周, 0-6): " week
    do
      goback $week "clear;show_menu" "show_menu \"\" 1"
      if [[ ! -n $(echo "$week" | gawk '/^(\*)(\/[1-9]([0-9]{1,2})?)?$|^([0-6])([\-\,]{1}([0-6]))?(\/[1-9]([0-9]{1,2})?)?$/{print $0}') && -n $week ]]; then
        warning "执行时间点(周)格式错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n执行时间点(周, 0-6): $week"
    clear && echo -e $sub_title
    echo
    if [[ ! -n $minute ]]; then minute="*"; fi
    if [[ ! -n $hour ]]; then hour="*"; fi
    if [[ ! -n $day ]]; then day="*"; fi
    if [[ ! -n $month ]]; then month="*"; fi
    if [[ ! -n $week ]]; then week="*"; fi
    (crontab -l ; echo "$minute $hour $day $month $week $newquest") | crontab - > /dev/null 2>&1
    echo -e "- ${yellow}自定义任务已添加${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  2)
    clear
    sub_title="每日任务\n------------------------"
    echo -e $sub_title
    while read -p "需要执行的命令: " newquest
    do
      goback $newquest "clear;show_menu" "show_menu \"\" 2"
      if [[ ! -n $newquest ]]; then
        warning "请输入需要执行的命令" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n需要执行的命令: $newquest"
    clear && echo -e $sub_title
    while read -p "执行时间点(格式 2:30): " time
    do
      goback $time "clear;show_menu" "show_menu \"\" 2"
      if [[ ! -n $(echo "$time" | gawk '/^([0-9]|[1][0-9]|[2][0-3])(\:([0-5][0-9]))?$/{print $0}') && -n $time ]]; then
        warning "执行时间点格式错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n执行时间点(格式 2:30): $time"
    clear && echo -e $sub_title
    if [[ ! -n $time ]]; then
      (crontab -l ; echo "$(expr $RANDOM % 59 + 1) $(expr $RANDOM % 23 + 1) * * * $newquest") | crontab - > /dev/null 2>&1
    elif [[ ! -n $(echo "$time" | awk -F ":" '{print $2}') ]]; then
      (crontab -l ; echo "0 $time * * * $newquest") | crontab - > /dev/null 2>&1
    else
      minute=`echo "$time" | awk -F ":" '{print $2}'`
      hour=`echo "$time" | awk -F ":" '{print $1}'`
      (crontab -l ; echo "$(expr $minute + 0) $hour * * * $newquest") | crontab - > /dev/null 2>&1
    fi
    echo -e "- ${yellow}每日任务已添加${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  3)
    clear
    echo "删除任务"
    echo "------------------------"
    echo
    crontab -l
    echo
    if [[ -n $3 ]]; then
      echo -e "${red}$3${plain}"
      echo
    fi
    while read -p "输入任务关键字: " kquest
    do
      goback $kquest "clear;show_menu"
      if [[ ! -n $kquest ]]; then
        show_menu "" 3 "请输入任务关键字"
        continue
      fi
      break
    done
    echo
    crontab -l | grep -v "$kquest" | crontab -
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