#! /bin/bash
SYS_DISK=`df -h /boot | grep -E "^/dev" | awk -F ' ' '{print $1}' | sed 's/[1-9]$//'`

# 磁盘列表
get_disk_list() {
  ALL_DISKS=(`fdisk -l | grep -E "(Disk|磁盘) /dev/(s|v)d" | sed -E 's/(：|\: |\, )/ /g'| awk -F " " '{print $2}'`)
  MOUNT_LIST=() # 可挂载列表
  REMOVE_LIST=() # 可卸载列表
  printf "%-22s %-12s %-12s\n" "磁盘" "大小" "挂载点"
  for n in $(seq 1 $(fdisk -l | grep -E "(Disk|磁盘) /dev/(s|v)d" | wc -l));
  do
    node=`fdisk -l | grep -E "(Disk|磁盘) /dev/(s|v)d" | sort | sed -n "${n}p" | sed -E 's/(：|\: |\, )/ /g'`
    name=`echo $node | awk -F " " '{print $2}'`
    size=`to_size $(echo $node | awk -F " " '{print $5}')`
    point=`df -h | grep -E "^$name" | awk -F ' ' '{print $6}'`
    if [[ ! -n $point ]]; then
      MOUNT_LIST[${#MOUNT_LIST[@]}]="$name"
      if [[ $1 == 'remove' ]]; then
        continue
      fi
    elif [[ $name != $SYS_DISK && -n $point ]]; then
      REMOVE_LIST[${#REMOVE_LIST[@]}]="$name"
      if [[ $1 == 'mount' ]]; then
        continue
      fi
    elif [[ $1 == 'remove' ]]; then
      continue
    elif [[ $1 == 'mount' ]]; then
      continue
    fi
    printf "%-20s %-10s %-10s\n" "$name" "$size" "$point"
  done
  unset node name size point
}

# 挂载磁盘
mount_disk() {
  clear
  sub_title="挂载磁盘分区\n------------------------"
  sub_title="$sub_title\n挂载磁盘: $1"
  echo -e "$sub_title"
  while read -p "选择挂载点: " point
  do
    goback $point "clear;show_menu" "show_menu \"\" $2"
    if [[ ! -n $point ]]; then
      warning "请选择挂载点" "$sub_title"
      continue
    fi
    if [[ ! -n $(echo "$point" | gawk '/^(\/)[^/s]*/{print $0}') ]]; then
      warning "挂载点路径格式错误" "$sub_title"
      continue
    fi
    break
  done
  sub_title="$sub_title\n选择挂载点: $point"
  clear
  echo -e "$sub_title"
  confirm "确定要执行挂载任务吗?" "n"
  if [[ $? == 1 ]]; then
    clear
    show_menu
    return
  fi
  echo
  echo "执行挂载任务"
  echo
  volume=`fdisk -lu $1 | grep -E "^$1" | awk -F ' ' '{print $1}' | sed -n "1p"`
  if [[ -n $volume ]]; then
    # 如果分区已存在
    confirm "分区已存在，是否要格式化磁盘?" "n"
    if [[ $? == 0 ]]; then
      mkfs -t ext4 $volume
    fi
  else
    # 创建分区
    fdisk -u $1 <<EOF
n
p
1


wq
EOF
    # 格式化分区
    volume=`fdisk -lu $1 | grep -E "^$1" | awk -F ' ' '{print $1}' | sed -n "1p"`
    mkfs -t ext4 $volume
  fi
  # 备份分区表
  cp /etc/fstab /etc/fstab.bak
  # 写入分区表
  echo `blkid $volume | awk '{print $2}' | sed 's/\"//g'` $point ext4 defaults 0 0 >> /etc/fstab
  # 创建挂载目录
  mkdir -p $point
  # 挂载分区
  mount -a
  unset sub_title volume point
  echo
  df -Th | grep -v -E "overlay|tmpfs|/dev/dm"
}

# 卸载磁盘
remove_disk() {
  clear
  echo "卸载磁盘分区"
  echo "------------------------"
  echo "卸载磁盘: $1"
  echo
  confirm "确定要执行卸载任务吗?" "n"
  if [[ $? == 1 ]]; then
    clear
    show_menu
    return
  fi
  for n in $(seq 1 $(df -h | grep -E "^$1" | wc -l));
  do
    point=`df -h | grep -E "^$1" | sort | sed -n "${n}p" | awk -F ' ' '{print $6}'`
    sed -i "/$(echo $point | sed -E 's/\//\\\//') /d" /etc/fstab
    umount $point
  done
  unset sub_title point
  echo
  df -Th | grep -v -E "overlay|tmpfs|/dev/dm"
}

# 扩容磁盘
expand_disk() {
  clear
  echo "扩容磁盘分区"
  echo "------------------------"
  echo "扩容磁盘: $1"
  echo
  confirm "确定要执行扩容任务吗?" "n"
  if [[ $? == 1 ]]; then
    clear
    show_menu
    return
  fi
  if !(command -v growpart &> /dev/null); then
    if (command -v apt &> /dev/null); then
      apt install -y cloud-utils
    elif (command -v yum &> /dev/null); then
      yum install -y cloud-utils-growpartss
    elif (command -v apk &> /dev/null); then
      apk add cloud-utils
    fi
  fi
  curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install xfs_growfs
  # 扩容分区
  LANG=en_US.UTF-8
  growpart "$1" 1
  for n in $(seq 1 $(fdisk -lu $1 | grep -E "^$1" | wc -l));
  do
    # 刷新分区大小
    volume=`fdisk -lu $1 | grep -E "^$1" | sort | sed -n "${n}p" | awk -F ' ' '{print $1}'`
    type=`df -Th | grep "$volume" | awk -F " " '{print $2}'`
    if [[ $type == 'xfs' ]]; then
      xfs_growfs "$volume"
    elif (echo $type | grep -E -q "^ext"); then
      resize2fs "$volume"
    fi
  done
  unset volume type
  echo
  df -Th | grep -v -E "overlay|tmpfs|/dev/dm"
}
