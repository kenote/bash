#! /bin/bash

compose_options() {
  clear
  echo "Compose项目"
  echo "------------------------"
  echo
  compose_list
  echo
  echo "操作选项"
  echo "---------------------------------------------"
  echo "1. 启动指定项目         2. 停止指定项目"
  echo "3. 重启指定项目         4. 删除指定项目"
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
    sub_title="启动指定项目\n------------------------"
    echo -e $sub_title
    echo
    compose_list
    echo
    while read -p "项目名称: " name
    do
      goback $name "clear;compose_options"
      if [[ ! -n $name ]]; then
        warning "请输入项目名称！" "$sub_title" "compose_list"
        continue
      fi
      break
    done
    sub_title="$sub_title\n项目名称: $name"
    clear && echo -e $sub_title
    echo
    if [[ -n $(echo $name | gawk '/^\/(\w+\/?)+$/{print $0}') ]]; then
      if [[ -d $name ]]; then
        cd $name
        project=$(echo $projects | jq -r ".[] | select(.working_dir == \"$name\")")
        if [[ -n $(echo $project | jq -r ".config_file") ]]; then
          docker-compose start
        elif [[ -n $(ls $name -1 | grep -E "compose.ya?ml$") ]]; then
          docker-compose up -d
        else
          echo -e "- 输入的项目缺少配置文件"
        fi
      else
        echo -e "- 输入的项目路径不存在"
      fi
    else
      project=$(echo $projects | jq -r ".[] | select(.name == \"$name\")")
      if [[ -n $(echo $project | jq -r ".config_file") ]]; then
        cd $(echo $project | jq -r ".working_dir")
        docker-compose start
      else
        echo -e "- 输入的项目名称不存在"
      fi
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    compose_options
  ;;
  2)
    clear
    sub_title="停止指定项目\n------------------------"
    echo -e $sub_title
    echo
    compose_list
    echo
    while read -p "项目名称: " name
    do
      goback $name "clear;compose_options"
      if [[ ! -n $name ]]; then
        warning "请输入项目名称！" "$sub_title" "compose_list"
        continue
      fi
      break
    done
    sub_title="$sub_title\n项目名称: $name"
    clear && echo -e $sub_title
    echo
    project=$(echo $projects | jq -r ".[] | select(.name == \"$name\")")
    if [[ -n $(echo $project | jq -r ".config_file") ]]; then
      cd $(echo $project | jq -r ".working_dir")
      docker-compose stop
    else
      echo -e "- 输入的项目名称不存在"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    compose_options
  ;;
  3)
    clear
    sub_title="重启指定项目\n------------------------"
    echo -e $sub_title
    echo
    compose_list
    echo
    while read -p "项目名称: " name
    do
      goback $name "clear;compose_options"
      if [[ ! -n $name ]]; then
        warning "请输入项目名称！" "$sub_title" "compose_list"
        continue
      fi
      break
    done
    sub_title="$sub_title\n项目名称: $name"
    clear && echo -e $sub_title
    echo
    project=$(echo $projects | jq -r ".[] | select(.name == \"$name\")")
    if [[ -n $(echo $project | jq -r ".config_file") ]]; then
      cd $(echo $project | jq -r ".working_dir")
      docker-compose restart
    else
      echo -e "- 输入的项目名称不存在"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    compose_options
  ;;
  4)
    clear
    sub_title="删除指定项目\n------------------------"
    echo -e $sub_title
    echo
    compose_list
    echo
    while read -p "项目名称: " name
    do
      goback $name "clear;compose_options"
      if [[ ! -n $name ]]; then
        warning "请输入项目名称！" "$sub_title" "compose_list"
        continue
      fi
      break
    done
    sub_title="$sub_title\n项目名称: $name"
    clear && echo -e $sub_title
    echo
    project=$(echo $projects | jq -r ".[] | select(.name == \"$name\")")
    if [[ -n $(echo $project | jq -r ".config_file") ]]; then
      cd $(echo $project | jq -r ".working_dir")
      docker-compose down
    else
      echo -e "- 输入的项目名称不存在"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    compose_options
  ;;

  0)
    clear
    show_menu
  ;;
  *)
    clear
    compose_options "请输入正确的数字"
  ;;
  esac
}

compose_list() {
  projects="[]"
  working_dirs=()
  printf "%-30s %-15s %-30s\n" "NAME" "STATUS" "WORKING_PATH"
  echo "-------------------------------------------------------------------------------------"
  for container_id in $(docker ps -a -q); do
    info=`docker inspect ${container_id} --format '{{ json .Config.Labels }}'`
    name=`echo $info | jq -r '.["com.docker.compose.project"]'`
    if [[ -n $(echo $name | grep "null") ]]; then
      continue
    fi
    config_file=`echo $info | jq -r '.["com.docker.compose.project.config_files"]'`
    working_dir=`echo $info | jq -r '.["com.docker.compose.project.working_dir"]'`
    if (echo ${working_dirs[@]} | grep -wq "$working_dir"); then
      continue
    fi
    status=`docker inspect ${container_id} --format '{{ json .State.Status }}' | sed "s/\"//g"`
    json="{\"name\":\"$name\",\"working_dir\":\"$working_dir\",\"config_file\":\"$config_file\"}"
    projects=`echo $projects | jq -r ".[$(echo $projects | jq -r '. | length')]=$json"`
    working_dirs[${#working_dirs[@]}]=$working_dir
    printf "%-30s %-15s %-30s\n" "$name" "$status" "$working_dir"
    unset info name config_file working_dir json status
  done
}