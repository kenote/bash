#! /bin/bash
CURRENT_DIR=$(cd $(dirname $0);pwd)

update_package() {
  PKG_RELEASE=`curl -s https://api.github.com/repos/$1/releases/latest | jq -r ".tag_name"`
  if [[ ! -n $PKG_RELEASE ]]; then
    return
  fi
  name=$(echo $1 | awk -F "/" '{print $2}')
  mkdir -p $CURRENT_DIR/packages/$name
  if [[ ! -f $CURRENT_DIR/packages/$name/latest.txt ]]; then
    echo "0" > $CURRENT_DIR/packages/$name/latest.txt
  elif [[ -n $(cat $CURRENT_DIR/packages/$name/latest.txt | grep -E "^$PKG_RELEASE$") ]]; then
    return
  fi
  for file in $(curl -s https://api.github.com/repos/$1/releases/latest | jq -r ".assets[] | .name" | grep -E "$2")
  do
    wget --no-check-certificate -O $CURRENT_DIR/packages/$name/$file https://github.com/$1/releases/download/$PKG_RELEASE/$file
  done
  echo "$PKG_RELEASE" > $CURRENT_DIR/packages/$name/latest.txt
}

update_bash() {
  cd $CURRENT_DIR/kenote/bash
  git pull origin main
}

case $1 in
--install)
  if [[ ! -n $2 ]]; then
    MIRROR_PATH=/mnt/mirrors
  elif [[ -n $(echo "$(echo $2)" | gawk '/^(\/)[^/s]*/{print $0}') ]]; then
    MIRROR_PATH=$2
  else
    MIRROR_PATH=/mnt/$2
  fi
  # 创建目录
  mkdir -p $MIRROR_PATH/kenote
  # 拉取脚本
  wget -O $MIRROR_PATH/kenote.sh https://raw.githubusercontent.com/kenote/bash/main/kenote.sh
  chmod +x $MIRROR_PATH/kenote.sh
  # 克隆 kenote/bash
  rm -rf $MIRROR_PATH/kenote/bash
  git clone https://github.com/kenote/bash.git $MIRROR_PATH/kenote/bash
  # 更新 packages
  $MIRROR_PATH/kenote.sh --update
  # 添加计划任务
  $MIRROR_PATH/kenote.sh --cron
;;
--cron)
  # 添加计划任务
  crontab -l | grep -v "$CURRENT_DIR/kenote.sh" | crontab -
  if [[ -n $2 ]]; then
    (crontab -l;echo "$2 $CURRENT_DIR/kenote.sh --update") | crontab -
  else
    random_minute=`expr $RANDOM % 59 + 1`;
    random_hour=`expr $RANDOM % 23 + 1`;
    (crontab -l;echo "$random_minute $random_hour * * * $CURRENT_DIR/kenote.sh --update") | crontab -
  fi
  crontab -l
;;
--update)
  # 更新 kenote/bash
  update_bash
  # 更新 packages
  if [[ ! -f $CURRENT_DIR/packages.ini ]]; then
    echo -e "aristocratos/btop\nmikefarah/yq" > $MIRROR_PATH/packages.ini
  fi
  for name in $(cat $CURRENT_DIR/packages.ini)
  do
    update_package $name
  done
;;
esac