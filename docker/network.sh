#! /bin/bash

network_list() {
  printf "%-30s %-30s %-30s\n" "容器名称" "网络名称" "IP地址"
  echo "--------------------------------------------------------------------"
  for container_id in $(docker ps -q); do
    container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

    container_name=$(echo "$container_info" | awk '{print $1}' | sed 's/^\///')
    network_info=$(echo "$container_info" | cut -d' ' -f2-)

    while IFS= read -r line; do
      network_name=$(echo "$line" | awk '{print $1}')
      ip_address=$(echo "$line" | awk '{print $2}')

      printf "%-26s %-26s %-15s\n" "$container_name" "$network_name" "$ip_address"
    done <<< "$network_info"
  done
  unset container_info container_name network_info network_name ip_address
}

network_options() {
  clear
  echo "网络管理"
  echo "------------------------"
  echo
  docker network ls
  echo
  network_list

  echo
  echo "操作选项"
  echo "---------------------------------------------"
  echo "1. 创建网络     2. 删除网络     3. 查看网络配置"
  echo "4. 加入网络     5. 移除网络     6. 清理无用网络"
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
    sub_title="创建网络\n------------------------"
    echo -e $sub_title
    while read -p "网络名称: " name
    do
      goback $name "clear;network_options"
      if [[ ! -n $name ]]; then
        warning "请输入网络名称！" "$sub_title"
        continue
      fi
      if [[ ! -n $(echo "$name" | gawk '/^[a-zA-Z]{1}[0-9a-zA-Z\-]{3,19}$/{print $0}') ]]; then
        warning "网络名称格式错误！" "$sub_title"
        continue
      fi
      if [[ -n $(docker network ls | awk '{if (NR>1){print $2}}' | grep -E "^$name$") ]]; then
        warning "网络名称已存在！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n网络名称: $name"
    clear && echo -e $sub_title
    echo
    docker network create $name
    echo
    read -n1 -p "按任意键继续" key
    clear
    network_options
  ;;
  2)
    clear
    sub_title="删除网络\n------------------------"
    echo -e $sub_title
    echo
    docker network ls
    echo
    while read -p "网络名称/ID: " name
    do
      goback $name "clear;network_options"
      if [[ ! -n $name ]]; then
        warning "请输入网络名称/ID！" "$sub_title" "docker network ls"
        continue
      fi
      if [[ ! -n $(docker network ls | awk '{if (NR>1){print $1" "$2}}' | grep -E "^$name | $name$") ]]; then
        warning "网络名称/ID不存在！" "$sub_title" "docker network ls"
        continue
      fi
      break
    done
    sub_title="$sub_title\n网络名称/ID: $name"
    clear && echo -e $sub_title
    echo
    docker network rm $name
    echo
    read -n1 -p "按任意键继续" key
    clear
    network_options
  ;;
  3)
    clear
    sub_title="查看网络配置\n------------------------"
    echo -e $sub_title
    echo
    docker network ls
    echo
    while read -p "网络名称/ID: " name
    do
      goback $name "clear;network_options"
      if [[ ! -n $name ]]; then
        warning "请输入网络名称/ID！" "$sub_title" "docker network ls"
        continue
      fi
      if [[ ! -n $(docker network ls | awk '{if (NR>1){print $1" "$2}}' | grep -E "^$name | $name$") ]]; then
        warning "网络名称/ID不存在！" "$sub_title" "docker network ls"
        continue
      fi
      break
    done
    sub_title="$sub_title\n网络名称/ID: $name"
    clear && echo -e $sub_title
    echo
    docker network inspect $name
    echo
    read -n1 -p "按任意键继续" key
    clear
    network_options
  ;;
  4)
    clear
    sub_fullbash="get_sub_note \"加入网络\" 'docker network ls && echo && docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Networks}}\"'"
    eval $sub_fullbash
    while read -p "选择网络: " network
    do
      goback $network "clear;network_options"
      if [[ ! -n $network ]]; then
        warning "请输入网络名称！" "" "$sub_fullbash"
        continue
      fi
      if [[ ! -n $(docker network ls | awk '{if (NR>1){print $1" "$2}}' | grep -E "^$network | $network$") ]]; then
        warning "选择的网络不存在！" "" "$sub_fullbash"
        continue
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"选择网络: $network\""
    clear && eval $sub_fullbash
    while read -p "选择容器: " container
    do
      goback $container "clear;network_options"
      if [[ ! -n $container ]]; then
        warning "请输入容器名称！" "" "$sub_fullbash"
        continue
      fi
      if [[ ! -n $(docker ps --format "{{.ID}} {{.Names}}" | grep -E "^$container | $container$") ]]; then
        warning "选择的容器不存在！" "" "$sub_fullbash"
        continue
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"选择容器: $container\""
    clear && eval $sub_fullbash
    echo
    docker network connect $network $container
    echo
    read -n1 -p "按任意键继续" key
    clear
    network_options
  ;;
  5)
    clear
    sub_fullbash="get_sub_note \"移除网络\" 'network_list'"
    eval $sub_fullbash
    while read -p "选择网络: " network
    do
      goback $network "clear;network_options"
      if [[ ! -n $network ]]; then
        warning "请输入网络名称！" "" "$sub_fullbash"
        continue
      fi
      if [[ ! -n $(docker network ls | awk '{if (NR>1){print $1" "$2}}' | grep -E "^$network | $network$") ]]; then
        warning "选择的网络不存在！" "" "$sub_fullbash"
        continue
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"选择网络: $network\""
    clear && eval $sub_fullbash
    while read -p "选择容器: " container
    do
      goback $container "clear;network_options"
      if [[ ! -n $container ]]; then
        warning "请输入容器名称！" "" "$sub_fullbash"
        continue
      fi
      if [[ ! -n $(docker ps --format "{{.ID}} {{.Names}}" | grep -E "^$container | $container$") ]]; then
        warning "选择的容器不存在！" "" "$sub_fullbash"
        continue
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"选择容器: $container\""
    clear && eval $sub_fullbash
    echo
    docker network disconnect $network $container
    echo
    read -n1 -p "按任意键继续" key
    clear
    network_options
  ;;
  6)
    clear
    echo "清理无用网络"
    echo "------------------------"
    echo
    docker network prune
    echo
    read -n1 -p "按任意键继续" key
    clear
    network_options
  ;;
  0)
    clear
    show_menu
  ;;
  *)
    clear
    network_options "请输入正确的数字"
  ;;
  esac
}