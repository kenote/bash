#! /bin/bash

container_options() {
  clear
  echo "容器管理"
  echo "------------------------"
  echo
  docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
  echo
  echo "操作选项"
  echo "---------------------------------------------"
  echo "1. 创建新容器"
  echo "---------------------------------------------"
  echo "2. 启动指定容器         3. 启动所有容器"
  echo "4. 停止指定容器         5. 停止所有容器"
  echo "6. 重启指定容器         7. 重启所有容器"
  echo "8. 删除指定容器         9. 删除所有容器"
  echo "---------------------------------------------"
  echo "11. 进入指定容器       12. 查看容器日志"
  echo "13. 导出容器快照       14. 导入容器快照"
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
    sub_title="创建新容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    read -p "" commandline
    if [[ -n $(echo "$commandline" | gawk "/^(docker\s+run)/{print $0}") ]]; then
      eval "$commandline"
    else
      echo -e "- 非Docker指令"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  2)
    clear
    sub_title="启动指定容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    while read -p "容器名/ID: " name
    do
      goback $name "clear;container_options"
      if [[ ! -n $name ]]; then
        warning "请输入容器名/ID！" "$sub_title" "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n容器名/ID: $name"
    clear && echo -e $sub_title
    echo
    if [[ -n $(docker inspect $name | jq -r '.[0].State.Status' | grep 'running' ) ]]; then
      docker restart $name
    else
      docker start $name
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  3)
    clear
    sub_title="启动所有容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    if [ $(docker ps -a -q | wc -l) -gt 0 ]; then
      docker start $(docker ps -a -q)
    else
      echo "- 没有可启动的容器"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  4)
    clear
    sub_title="停止指定容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    while read -p "容器名/ID: " name
    do
      goback $name "clear;container_options"
      if [[ ! -n $name ]]; then
        warning "请输入容器名/ID！" "$sub_title" "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n容器名/ID: $name"
    clear && echo -e $sub_title
    echo
    docker stop $name
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  5)
    clear
    sub_title="停止所有容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    if [ $(docker ps -q | wc -l) -gt 0 ]; then
      docker stop $(docker ps -q)
    else
      echo "- 没有可停止的容器"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  6)
    clear
    sub_title="重启指定容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    while read -p "容器名/ID: " name
    do
      goback $name "clear;container_options"
      if [[ ! -n $name ]]; then
        warning "请输入容器名/ID！" "$sub_title" "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n容器名/ID: $name"
    clear && echo -e $sub_title
    echo
    docker restart $name
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  7)
    clear
    sub_title="重启所有容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    if [ $(docker ps -q | wc -l) -gt 0 ]; then
      docker restart $(docker ps -q)
    else
      echo "- 没有可启动的容器"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  8)
    clear
    sub_title="删除指定容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    while read -p "容器名/ID: " name
    do
      goback $name "clear;container_options"
      if [[ ! -n $name ]]; then
        warning "请输入容器名/ID！" "$sub_title" "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n容器名/ID: $name"
    clear && echo -e $sub_title
    echo
    docker rm -f $name
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  9)
    clear
    sub_title="删除所有容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    if [ $(docker ps -a -q | wc -l) -gt 0 ]; then
      docker rm -f $(docker ps -a -q)
    else
      echo "- 没有可删除的容器"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;

  11)
    clear
    sub_title="进入指定容器\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    while read -p "容器名/ID: " name
    do
      goback $name "clear;container_options"
      if [[ ! -n $name ]]; then
        warning "请输入容器名/ID！" "$sub_title" "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n容器名/ID: $name"
    clear && echo -e $sub_title
    while read -p "BIN指令(bash/sh/zsh): " binname
    do
      goback $binname "clear;container_options"
      if [[ ! -n $binname ]]; then
        warning "请选择BIN指令！" "$sub_title" "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}\""
        continue
      fi
      break
    done
    echo
    docker exec -it $name /bin/$binname
    echo
    read -n1 -p "按任意键继续" key
    clear
  ;;
  12)
    clear
    sub_title="查看容器日志\n------------------------"
    echo -e $sub_title
    echo
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}"
    echo
    while read -p "容器名/ID: " name
    do
      goback $name "clear;container_options"
      if [[ ! -n $name ]]; then
        warning "请输入容器名/ID！" "$sub_title" "docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}\""
        continue
      fi
      break
    done
    sub_title="$sub_title\n容器名/ID: $name"
    clear && echo -e $sub_title
    echo
    create_task "tmp_log" "docker logs -f $name"
    clear
    container_options
  ;;
  13)
    clear
    sub_fullbash="get_sub_note \"导出容器快照\" 'docker ps --format \"table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Size}}\t{{.CreatedAt}}\"'"
    eval $sub_fullbash
    while read -p "容器名/ID: " name
    do
      goback $name "clear;container_options"
      if [[ ! -n $name ]]; then
        warning "请输入容器名/ID！" "" "$sub_fullbash"
        continue
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"容器名/ID: $name\""
    clear && eval $sub_fullbash
    while read -p "导出文件: " tarfile
    do
      goback $tarfile "clear;container_options"
      if [[ ! -n $tarfile ]]; then
        warning "请输入导出文件名称！" "" "$sub_fullbash"
        continue
      fi
      if [[ ! -n $(echo $tarfile | gawk '/\.tar$/{print $0}') ]]; then
        tarfile="$tarfile.tar"
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"导出文件: $tarfile\""
    clear && eval $sub_fullbash
    echo
    echo "正在导出文件 -- $KENOTE_DOCKER_HOME/snapshot/$tarfile"
    if [[ ! -d "$KENOTE_DOCKER_HOME/snapshot" ]]; then
      mkdir -p "$KENOTE_DOCKER_HOME/snapshot"
    fi
    echo
    docker export $name > $KENOTE_DOCKER_HOME/snapshot/$tarfile
    echo "导出完毕！"
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;
  14)
    clear
    sub_fullbash="get_sub_note \"导入容器快照\" 'get_tar_list snapshot'"
    eval $sub_fullbash
    while read -p "快照文件: " name
    do
      goback $name "clear;container_options"
      if [[ ! -n $name ]]; then
        warning "请输入快照文件！" "" "$sub_fullbash"
        continue
      fi
      if [[ ! -n $(echo $name | gawk '/^https?\:(\/){2}/{print $0}' ) ]]; then
        if [[ ! -f "$KENOTE_DOCKER_HOME/snapshot/$name" ]]; then
          warning "快照文件不存在！" "" "$sub_fullbash"
          continue
        fi
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"快照文件: $name\""
    clear && eval $sub_fullbash
    while read -p "导出镜像名: " image
    do
      goback $image "clear;container_options"
      if [[ ! -n $image ]]; then
        warning "请输入导出镜像名！" "" "$sub_fullbash"
        continue
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"导出镜像名: $image\""
    clear && eval $sub_fullbash
    echo
    if [[ -n $(echo $name | gawk '/^https?\:(\/){2}/{print $0}' ) ]]; then
      echo "正在导入快照文件 -- $name"
      echo
      docker import $name $image
    else
      echo "正在导入快照文件 -- $KENOTE_DOCKER_HOME/snapshot/$name"
      echo
      cat $KENOTE_DOCKER_HOME/snapshot/$name | docker import - $image
    fi
    echo "导入完成！"
    echo
    read -n1 -p "按任意键继续" key
    clear
    container_options
  ;;

  0)
    clear
    show_menu
  ;;
  *)
    clear
    container_options "请输入正确的数字"
  ;;
  esac
}

# 创建会话任务
create_task() {
  del_task "$1"
  tmux new -d -s "$1"
  tmux send-keys -t "$1" "clear;$2;bash $CURRENT_DIR/docker.sh --del-task $1;exit" ENTER
  tmux a -t "$1"
}

# 删除会话任务
del_task() {
  if [[ -n $(tmux ls | grep "^$1:") ]]; then
    tmux kill-session -t "$1"
  fi
}