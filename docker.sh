#! /bin/bash
source $(cd $(dirname $0);pwd)/core.sh
source $(cd $(dirname $0);pwd)/docker/init.sh
source $(cd $(dirname $0);pwd)/docker/container.sh
source $(cd $(dirname $0);pwd)/docker/image.sh
source $(cd $(dirname $0);pwd)/docker/volume.sh
source $(cd $(dirname $0);pwd)/docker/network.sh

show_menu() {
  choice=$2
  if [[ ! -n $2 ]]; then
    echo "> Docker管理"
    echo "------------------------"
    echo "1. 容器管理"
    echo "2. 镜像管理"
    echo "3. 数据卷管理"
    echo "4. 网络管理"
    echo "5. Stack管理"
    echo "------------------------"
    echo "11. 启动服务"
    echo "12. 停止服务"
    echo "13. 重启服务"
    echo "14. 查看信息"
    echo "15. 镜像源管理"
    echo "------------------------"
    echo "00. 安装docker环境"
    echo "99. 卸载docker环境"
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

  2)
    clear
    is_docker_env
    image_options
    clear
    show_menu
  ;;
  3)
    clear
    is_docker_env
    volume_options
    clear
    show_menu
  ;;
  4)
    clear
    is_docker_env
    network_options
    clear
    show_menu
  ;;

  11)
    clear
    is_docker_env
    if [[ $(systemctl status docker | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'running' ]]; then
      systemctl restart docker
    else
      systemctl start docker
    fi
    systemctl status docker
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  12)
    clear
    is_docker_env
    if [[ $(systemctl status docker | grep "active" | cut -d '(' -f2|cut -d ')' -f1) == 'running' ]]; then
      systemctl stop docker
    fi
    systemctl status docker
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  13)
    clear
    is_docker_env
    systemctl restart docker
    systemctl status docker
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  14)
    clear
    is_docker_env
    echo "Docker版本"
    echo "------------------------"
    docker --version
    docker-compose --version
    echo
    docker system df
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  15)
    clear
    is_docker_env
    echo "镜像源管理"
    echo "------------------------"
    mirror_options
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  00)
    clear
    if !(command -v docker &> /dev/null); then
      echo
      install_docker
    fi
    if !(command -v docker-compose &> /dev/null); then
      ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin
    fi
    echo
    echo -e "- ${green}Docker 初始化完成${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
  ;;
  99)
    clear
    if (command -v docker &> /dev/null); then
      echo
      confirm "确定要卸载 docker 吗?" "n"
      if [[ $? == 0 ]]; then
        remove_docker
        echo
        echo -e "- ${green}docker 卸载完成${plain}"
      else
        clear
        show_menu
        return
      fi
    else
      echo
      echo -e "- ${yellow}docker 尚未安装${plain}"
    fi
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
init_docker $KENOTE_DOCKER_HOME
show_menu