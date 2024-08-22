#! /bin/bash

image_options() {
  clear
  echo "镜像管理"
  echo "------------------------"
  echo
  docker images
  echo
  echo "操作选项"
  echo "---------------------------------------------"
  echo "1. 拉取镜像       2. 编译镜像       3. 删除镜像"
  echo "4. 查看镜像       5. 导出镜像       6. 导入镜像"
  echo "7. 删除无效镜像   8. 删除不使用的镜像"
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
    sub_title="拉取镜像\n------------------------"
    echo -e $sub_title
    while read -p "镜像名称: " name
    do
      goback $name "clear;image_options"
      if [[ ! -n $name ]]; then
        warning "请输入镜像名称！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n镜像名称: $name"
    clear && echo -e $sub_title
    echo
    docker pull $name
    echo
    read -n1 -p "按任意键继续" key
    clear
    image_options
  ;;
  2)
    clear
    sub_title="编译镜像\n------------------------"
    echo -e $sub_title
    while read -p "Dockerfile路径: " file
    do
      goback $file "clear;image_options"
      if [[ ! -n $file ]]; then
        warning "请输入Dockerfile路径！" "$sub_title"
        continue
      fi
      if [[ -f $(parse_path $file) ]]; then
        dockerfile="$(parse_path $file)"
      elif [[ -d $(parse_path $file) ]]; then
        if [[ -f "$(parse_path $file)/Dockerfile" ]]; then
          dockerfile="$(parse_path $file)/Dockerfile"
        else
          warning "Dockerfile文件不存在！" "$sub_title"
          continue
        fi
      else
        warning "Dockerfile路径不存在！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\nDockerfile路径: $(parse_path $file)"
    clear && echo -e $sub_title
    while read -p "镜像命名: " tagname
    do
      goback $tagname "clear;image_options"
      if [[ ! -n $tagname ]]; then
        warning "请输入镜像命名！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n镜像命名: $tagname"
    clear && echo -e $sub_title
    echo
    cd $(dirname $dockerfile)
    docker build --file $(basename $dockerfile) --platform=linux/amd64 --tag $tagname .
    docker builder prune
    echo
    read -n1 -p "按任意键继续" key
    clear
    image_options
  ;;
  3)
    clear
    sub_title="删除镜像\n------------------------"
    echo -e $sub_title
    echo
    docker images
    echo
    while read -p "镜像名称/ID: " name
    do
      goback $name "clear;image_options" "docker images"
      if [[ ! -n $name ]]; then
        warning "请输入镜像名称/ID！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n镜像名称/ID: $name"
    clear && echo -e $sub_title
    echo
    docker rmi -f $name
    echo
    read -n1 -p "按任意键继续" key
    clear
    image_options
  ;;
  4)
    clear
    sub_title="查看镜像\n------------------------"
    echo -e $sub_title
    echo
    docker images
    echo
    while read -p "镜像名称/ID: " name
    do
      goback $name "clear;image_options" "docker images"
      if [[ ! -n $name ]]; then
        warning "请输入镜像名称/ID！" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n镜像名称/ID: $name"
    clear && echo -e $sub_title
    echo
    docker inspect $name | jq -r '.[]'
    echo
    read -n1 -p "按任意键继续" key
    clear
    image_options
  ;;
  5)
    clear
    sub_fullbash="get_sub_note \"导出镜像\" 'docker images'"
    eval $sub_fullbash
    while read -p "镜像名称: " name
    do
      goback $name "clear;image_options" "docker images"
      if [[ ! -n $name ]]; then
        warning "请输入镜像名称！" "" "$sub_fullbash"
        continue
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"镜像名称: $name\""
    clear && eval $sub_fullbash
    while read -p "导出文件: " tarfile
    do
      goback $tarfile "clear;image_options" "docker images"
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
    echo "正在导出文件 -- $KENOTE_DOCKER_HOME/image/$tarfile"
    if [[ ! -d "$KENOTE_DOCKER_HOME/image" ]]; then
      mkdir -p "$KENOTE_DOCKER_HOME/image"
    fi
    echo
    docker save > $KENOTE_DOCKER_HOME/image/$tarfile $name
    echo "导出完毕！"
    echo
    read -n1 -p "按任意键继续" key
    clear
    image_options
  ;;
  6)
    clear
    sub_fullbash="get_sub_note \"导入镜像\" 'get_tar_list image'"
    eval $sub_fullbash
    while read -p "文件名: " name
    do
      goback $name "clear;image_options" "docker images"
      if [[ ! -n $name ]]; then
        warning "请输入文件名！" "" "$sub_fullbash"
        continue
      fi
      if [[ ! -f "$KENOTE_DOCKER_HOME/image/$name" ]]; then
        warning "文件不存在！" "" "$sub_fullbash"
        continue
      fi
      break
    done
    sub_fullbash="$sub_fullbash && echo \"文件名: $name\""
    clear && eval $sub_fullbash
    echo
    echo "正在导入文件 -- $KENOTE_DOCKER_HOME/image/$name"
    echo
    docker load < "$KENOTE_DOCKER_HOME/image/$name"
    echo "导入完成！"
    echo
    read -n1 -p "按任意键继续" key
    clear
    image_options
  ;;
  7)
    clear
    echo "删除无效镜像"
    echo "------------------------"
    echo
    if [[ -n $(docker images -f "dangling=true" -q) ]]; then
      docker rmi $(docker images -f "dangling=true" -q) --force
    else
      echo -e "${yellow}No images to remove.${plain}"
    fi
    echo
    read -n1 -p "按任意键继续" key
    clear
    image_options
  ;;
  8)
    clear
    echo "删除不使用的镜像"
    echo "------------------------"
    echo
    docker image prune -a
    echo
    read -n1 -p "按任意键继续" key
    clear
    image_options
  ;;

  0)
    clear
    show_menu
  ;;
  *)
    clear
    image_options "请输入正确的数字"
  ;;
  esac
}