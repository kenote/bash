#! /bin/bash

RULES_FILE="/mnt/rules.v4"
SYSTEM_RULES=$(find /etc -name "rules.v4" -o -name "iptables" | grep -E "^(\/etc\/iptables\/|\/etc\/sysconfig\/)")

# 更新规则
update_rules() {
  sudo cp -f $RULES_FILE $SYSTEM_RULES
  iptables-restore < $SYSTEM_RULES
}

# 安装防火墙
install_iptables() {
  ssh_port=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --info ssh_port)
  if (cat /etc/os-release | grep -q -E -i "rocky|alma|rhel|oracle"); then
    systemctl stop firewalld
    systemctl disable firewalld
    yum install -y iptables-services ipset-service
    wget -O $RULES_FILE $KENOTE_BASH_MIRROR/system/rules.v4
    cat $RULES_FILE | sed "s/--dport 22 /--dport $ssh_port /g"
    update_rules
    systemctl start iptables
    systemctl enable iptables.service
    systemctl start ipset
    systemctl enable ipset.service
  elif (cat /etc/os-release | grep -q -E -i "debian|ubuntu"); then
    curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --remove iptables-persistent ufw
    apt update -y && apt install -y iptables iptables-persistent ipset-persistent
    wget -O $RULES_FILE $KENOTE_BASH_MIRROR/system/rules.v4
    cat $RULES_FILE | sed "s/--dport 22 /--dport $ssh_port /g"
    update_rules
    wget -O /etc/network/if-pre-up.d/iptables $KENOTE_BASH_MIRROR/system/iptables
    chmod +x /etc/network/if-pre-up.d/iptables
    systemctl start netfilter-persistent
    systemctl enable netfilter-persistent
  fi
  init_ipset blacklist whitelist
  unset ssh_port
}

# 删除防火墙
remove_iptables() {
  if (cat /etc/os-release | grep -q -E -i "rocky|alma|rhel"); then
    yum remove -y iptables-services ipset-service
  elif (cat /etc/os-release | grep -q -E -i "debian|ubuntu"); then
    apt remove -y iptables iptables-persistent ipset-persistent
  fi
}

# 获取规则列表
# get_rules_list input
# get_rules_list output
get_rules_list() {
  note=$(cat $RULES_FILE | grep -iE "\-a $1" | grep -E "(\-\-dport|\-s )")
  printf "%-10s %-15s %-15s %-30s %-10s\n" "PID" "PROTOCOL" "PORT" "SOURCE" "JUMP"
  echo "------------------------------------------------------------------------------------"
  for n in $(seq 1 $(echo "$note" | wc -l | awk -F " " '{print $1}')); do
    id=$(sed -nE "/$(echo "$note" | sed -n "${n}p")/=" $RULES_FILE | cut -d ":" -f 1)
    port=$(echo "$note" | sed -n "${n}p"  | awk '{split($0,a," --dport ");print a[2]}' | awk -F " " '{print $1}')
    protocol=$(echo "$note" | sed -n "${n}p"  | awk '{split($0,a," -p ");print a[2]}' | awk -F " " '{print $1}')
    jump=$(echo "$note" | sed -n "${n}p"  | awk '{split($0,a," -j ");print a[2]}' | awk -F " " '{print $1}')
    source=$(echo "$note" | sed -n "${n}p"  | awk '{split($0,a," -s ");print a[2]}' | awk -F " " '{print $1}')
    if [[ ! -n $source ]]; then source="0.0.0.0/0"; fi
    if [[ ! -n $protocol ]]; then protocol="all"; fi
    if [[ ! -n $port ]]; then port="--"; fi
    # echo "$jump" | gawk '/^(accept|drop|ACCEPT|DROP)$/{print $0}'
    printf "%-10s %-15s %-15s %-30s %-10s\n" "$id" "$(echo $protocol | tr [:lower:] [:upper:])" "$port" "$source" "$jump"
    unset port protocol jump
  done
}

# 添加入站端口规则
# set_input_port "80/tcp" "ACCEPT" 允许通过
# set_input_port "80/tcp" "DROP" 拒绝通过
# set_input_port "80/tcp" "DROP" "36.248.233.107" 拒绝指定IP通过
set_input_port() {
  jump="ACCEPT"
  if [[ -n $(echo $2 | gawk '/^(accept|drop|ACCEPT|DROP)$/{print $0}') ]]; then
    jump=`echo $2 | tr a-z A-Z`
  fi
  if [[ -n $(get_port_node "$1" "port" | grep ",") ]]; then
    multiport="-m multiport --dports"
  else
    multiport="--dport"
  fi
  note="-A INPUT $(get_iprange $3 "src") -p $(get_port_node "$1" "mode") $multiport $(get_port_node "$1" "port") -j $jump"
  line=$(sed -nE "/-A INPUT -j REJECT --reject-with icmp-host-prohibited/=" $RULES_FILE | cut -d ":" -f 1 | sed -n 1p)
  sed -i "$line i $note" $RULES_FILE
  unset jump multiport note line
}

# 添加出站端口规则
# set_output_port "80/tcp" "ACCEPT" 允许通过
# set_output_port "80/tcp" "DROP" 拒绝通过
# set_output_port "80/tcp" "DROP" "36.248.233.107" 拒绝指定IP通过
set_output_port() {
  jump="ACCEPT"
  if [[ -n $(echo $2 | gawk '/^(accept|drop|ACCEPT|DROP)$/{print $0}') ]]; then
    jump=`echo $2 | tr a-z A-Z`
  fi
  if [[ -n $(get_port_node "$1" "port" | grep ",") ]]; then
    multiport="-m multiport --dports"
  else
    multiport="--dport"
  fi
  note="-A OUTPUT $(get_iprange $3 "src") -p $(get_port_node "$1" "mode") $multiport $(get_port_node "$1" "port") -j $jump"
  line=$(sed -nE "/-A FORWARD -j REJECT --reject-with icmp-host-prohibited/=" $RULES_FILE | cut -d ":" -f 1 | sed -n 1p)
  sed -i "$line i $note" $RULES_FILE
  unset jump multiport note line
}

# 添加入站IP规则
set_input_ip() {
  jump="ACCEPT"
  if [[ -n $(echo $2 | gawk '/^(accept|drop|ACCEPT|DROP)$/{print $0}') ]]; then
    jump=`echo $2 | tr a-z A-Z`
  fi
  line=$(sed -nE "/-A INPUT -j REJECT --reject-with icmp-host-prohibited/=" $RULES_FILE | cut -d ":" -f 1 | sed -n 1p)
  sed -i "$line i -A INPUT $(get_iprange $1 "src") -j $jump" $RULES_FILE
  unset jump line
}

# 添加出站IP规则
set_output_ip() {
  jump="ACCEPT"
  if [[ -n $(echo $2 | gawk '/^(accept|drop|ACCEPT|DROP)$/{print $0}') ]]; then
    jump=`echo $2 | tr a-z A-Z`
  fi
  line=$(sed -nE "/-A FORWARD -j REJECT --reject-with icmp-host-prohibited/=" $RULES_FILE | cut -d ":" -f 1 | sed -n 1p)
  sed -i "$line i -A OUTPUT $(get_iprange $1 "src") -j $jump" $RULES_FILE
  unset jump line
}

# 删除规则
# del_rules 7 15 18
del_rules() {
  if [[ ! -n ${@:1} ]]; then
    return
  fi
  eval "sed -i $(echo $(printf " \-e '%sd'" ${@:1}) | sed 's/\\//g') $RULES_FILE"
}

# 初始化 ipset
init_ipset() {
  ipset destroy
  for name in ${@:1}
  do
    ipset create $name hash:net
  done
}

# 获取 ipset 信息
get_ipset_info() {
  ipset list $1 | tail -n +$(($(ipset list $1 | sed -nE "/Members:/=")+0))
}

# ipset 选项
# 放行指定IP(白名单)
ipset_opts() {
  clear
  echo "设置$1"
  echo "------------------------"
  get_ipset_info $2
  echo
  echo
  echo "操作选项"
  echo "----------------------------------------------------------------"
  echo "1. 添加$1         2. 删除$1         3. 清空$1"
  echo "4. 导出$1         5. 导入$1"
  echo "----------------------------------------------------------------"
  echo "0. 返回上一级"
  echo "------------------------"
  echo
  if [[ -n $3 ]]; then
    echo -e "${red}$3${plain}"
    echo
  fi
  read -p "请输入选择: " sub_choice

  case $sub_choice in
  1)
    clear
    sub_title="添加$1\n------------------------"
    echo -e $sub_title
    while read -p "指定IP: " ips
    do
      goback $ips "clear;ipset_opts $1 $2"
      if [[ ! -n $ips ]]; then
        warning "请填写指定IP" "$sub_title"
        continue
      fi
      is_param_true "is_ip" "${ips[*]}"
      if [[ $? == 1 ]]; then
        warning "IP地址格式存在错误" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n指定IP: $ips"
    clear && echo -e $sub_title
    echo
    for ip in ${ips[*]}; do
      if [[ ! -n $(get_ipset_info $2 | grep -E "^($ip)$") ]]; then
        ipset -exist add $2 $ip
      fi
    done
    echo
    clear
    ipset_opts $1 $2
  ;;
  2)
    clear
    sub_title="删除$1\n------------------------"
    echo -e $sub_title
    while read -p "指定IP: " ips
    do
      goback $ips "clear;ipset_opts $1 $2"
      if [[ ! -n $ips ]]; then
        warning "请填写指定IP" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n指定IP: $ips"
    clear && echo -e $sub_title
    echo
    for ip in ${ips[*]}; do
      if [[ -n $(get_ipset_info $2 | grep -E "^($ip)$") ]]; then
        ipset del $2 $ip
      fi
    done
    echo
    clear
    ipset_opts $1 $2
  ;;
  3)
    clear
    echo "清空$1"
    echo "------------------------"
    confirm "确定要清空${1}吗?" "n"
    if [[ $? == 0 ]]; then
      ipset flush $2
    fi
    echo
    clear
    ipset_opts $1 $2
  ;;
  4)
    clear
    sub_title="导出$1\n------------------------"
    echo -e $sub_title
    while read -p "文件路径(目录): " dir
    do
      goback $dir "clear;ipset_opts $1 $2"
      if [[ ! -n $dir ]]; then
        warning "请填写文件路径(目录)" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n文件路径(目录): $(parse_path $dir)"
    clear && echo -e $sub_title
    echo
    ipset save $2 -f $(parse_path $dir)/${2}.txt
    echo "导出$1 -- $(parse_path $dir)/${2}.txt"
    echo
    read -n1 -p "按任意键继续" key
    clear
    ipset_opts $1 $2
  ;;
  5)
    clear
    sub_title="导入$1\n------------------------"
    echo -e $sub_title
    while read -p "文件路径(目录): " dir
    do
      goback $dir "clear;ipset_opts $1 $2"
      if [[ ! -n $dir ]]; then
        warning "请填写文件路径(目录)" "$sub_title"
        continue
      fi
      if [[ ! -f $(parse_path $dir)/${2}.txt ]]; then
        warning "导入的文件不存在" "$sub_title"
        continue
      fi
      break
    done
    sub_title="$sub_title\n文件路径(目录): $(parse_path $dir)"
    clear && echo -e $sub_title
    echo
    ipset destroy $2
    ipset restore -f $(parse_path $dir)/${2}.txt
    echo "导入$1 -- $(parse_path $dir)/${2}.txt"
    echo
    read -n1 -p "按任意键继续" key
    clear
    ipset_opts $1 $2
  ;;
  0)
    clear
    show_menu
  ;;
  *)
    clear
    ipset_opts $1 $2 "请输入正确的数字"
  ;;
  esac
  unset sub_choice
}

# 开启转发功能
open_forwarding() {
  echo "1" > /proc/sys/net/ipv4/ip_forward
  if [[ -n $(cat /etc/sysctl.conf | grep -E "^(net.ipv4.ip_forward)") ]]; then
    sed -i 's/^net.ipv4.ip_forward \=.*/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
  else
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  fi
  sysctl -p
}

# 提取端口信息
# 443/tcp
# 80,443/tcp
# 6000:6500/tcp
get_port_node() {
  if [[ $2 == 'mode' ]]; then
    if [[ -n $(echo $1 | awk -F "/" '{print $2}' | gawk '/^(tcp|udp|icmp|all)$/{print $0}') ]]; then
      echo $1 | awk -F "/" '{print $2}'
    else
      echo "tcp"
    fi
  else
    echo $1 | awk -F "/" '{print $1}' | sed 's/\-/\:/g'
  fi
}

# 提取IP
# get_iprange "127.0.0.1" "src"
get_iprange() {
  if [[ -n $(echo "$1" | grep "-") ]]; then
    echo "-m iprange $(get_address $2 | awk -F " " "{print \$2 \" $1\"}")"
  else
    echo "$(get_address $2 | awk -F " " "{print \$1 \" $1\"}")"
  fi
}

# 获取地址头
get_address() {
  case $1 in
  src | s)
    echo "-s --src-range"
  ;;
  dst | d)
    echo "-d --dst-range"
  ;;
  esac
}

# 判断 iptables 环境
is_iptables_env() {
  if !(command -v iptables &> /dev/null); then
    echo -e "- ${yellow}iptables 未安装${plain}"
    echo
    read -n1 -p "按任意键继续" key
    clear
    show_menu
    return
  fi
}
