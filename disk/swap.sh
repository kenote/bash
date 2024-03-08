#! /bin/bash
SWAPFILE="/swapfile"

# swap 信息
get_swap_info() {
  swapfile=`cat /etc/fstab | grep " swap " | awk -F ' ' '{print $1}' | awk -v RS='' '{gsub("\n"," "); print}'`
  printf "%-32s %-12s %-12s %-12s\n" "路径" "容量" "已用" "可用"
  if [[ -n $swapfile ]]; then
    printf "%-30s %-10s %-10s %-10s\n" "$swapfile" $(free -b | awk 'NR==3{printf "%.fMB %.fMB %.fMB", $2/1024/1024, $3/1024/1024, $4/1024/1024}')
  fi
}

# 设置 swap
set_swap() {
  clear
  echo "设置交换分区"
  echo "------------------------"
  echo "交换分区大小(单位: Mb): $(echo "$1/1024" | bc)"
  echo
  confirm "确定要设置交换分区吗?" "n"
  if [[ $? == 1 ]]; then
    clear
    show_menu
    return
  fi
  if [[ -n $swapfile ]]; then
    remove_swap
  else
    swapfile="/swapfile"
  fi
  echo
  sudo dd if=/dev/zero of=$SWAPFILE bs=1024 count=$1 status=progress
  sudo chown root:root $SWAPFILE
  sudo chmod 0600 $SWAPFILE
  sudo mkswap $SWAPFILE
  sudo swapon $SWAPFILE
  echo "$SWAPFILE swap swap defaults 0 0" >> /etc/fstab
  echo
  get_swap_info
  unset swapfile
}

# 删除 swap
remove_swap() {
  if [[ ! -n $swapfile ]]; then
    return
  fi
  eval "sudo sed -i '/$(echo $swapfile | sed -e 's/\//\\\//g' | sed -e 's/\-/\\\-/g')/d' /etc/fstab"
  sudo echo "3" > /proc/sys/vm/drop_caches
  sudo swapoff $swapfile
  sudo rm -f $swapfile
  unset swapfile
}