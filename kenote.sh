#! /bin/bash
CURRENT_DIR=$(cd $(dirname $0);pwd)

update_btop() {
  BTOP_RELEASE=`curl -s https://api.github.com/repos/aristocratos/btop/releases/latest | jq -r ".tag_name"`
  if [[ ! -n $BTOP_RELEASE ]]; then
    return
  fi
  mkdir -p $CURRENT_DIR/packages/btop
  touch $CURRENT_DIR/packages/btop/latest.txt
  list=(aarch64 x86_64)
  for item in ${list[@]}
  do
    if [[ -f $CURRENT_DIR/packages/btop/btop-${item}-linux-musl.tbz && -n $(cat $CURRENT_DIR/packages/btop/latest.txt | grep -E -q "^$BTOP_RELEASE$") ]]; then
      continue
    fi
    wget --no-check-certificate -O $CURRENT_DIR/packages/btop/btop-${item}-linux-musl.tbz https://github.com/aristocratos/btop/releases/download/$BTOP_RELEASE/btop-${item}-linux-musl.tbz
  done
  echo "$BTOP_RELEASE" > $CURRENT_DIR/packages/btop/latest.txt
}

update_yq() {
  YQ_RELEASE=`curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r ".tag_name"`
  if [[ ! -n $YQ_RELEASE ]]; then
    return
  fi
  mkdir -p $CURRENT_DIR/packages/yq
  touch $CURRENT_DIR/packages/yq/latest.txt
  list=(arm64 amd64)
  for item in ${list[@]}
  do
    if [[ -f $CURRENT_DIR/packages/yq/yq_linux_${item} && -n $(cat $CURRENT_DIR/packages/yq/latest.txt | grep -E -q "^$YQ_RELEASE$") ]]; then
      continue
    fi
    wget --no-check-certificate -O $CURRENT_DIR/packages/yq/yq_linux_${item} https://github.com/mikefarah/yq/releases/download/$YQ_RELEASE/yq_linux_${item}
  done
  echo "$YQ_RELEASE" > $CURRENT_DIR/packages/yq/latest.txt
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
  $MIRROR_PATH/kenote.sh --btop
  $MIRROR_PATH/kenote.sh --yq
  # 添加计划任务
  $MIRROR_PATH/kenote.sh --cron
;;
--btop)
  update_btop
;;
--yq)
  update_yq
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
  update_btop
  update_yq
;;
esac