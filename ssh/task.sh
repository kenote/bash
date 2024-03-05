#! /bin/bash

# 创建会话任务
create_task() {
  while [ ${#} -gt 0 ]; do
    case "${1}" in
    --type)
      type=$2
      shift
    ;;
    --command)
      command=$2
      shift
    ;;
    *)
      echo -e "${red}Unknown parameter : $1${plain}"
      return 1
      shift
    ;;
    esac
    shift 1
  done

  # 如果指令在 tasks 中存在，直接连接视图
  pid=`cat ~/kenote_ssh/setting.json | jq -r ".tasks[] | select(.command == \"$command\").name"`
  if [[ -n $pid && -n $(tmux ls | grep "^$pid:") ]]; then
    tmux a -t "$pid"
    return
  fi

  task="{\"name\":\"$(uuidgen | tr 'A-Z' 'a-z' | head -c 8)\"}"
  task=`echo $task | jq -r ".command=\"$command\""`
  task=`echo $task | jq -r ".type=\"$type\""`
  task=`echo $task | jq -r ".associate=\"$(get_server_name "$command")\""`
  task=`echo $task | jq -r ".create=\"$(date +%s)\""`

  # 如果是数据传输，启用限速标签
  if [[ -n $(echo "$command" | gawk '/^(rsync)/{print $0}') ]]; then
    KENOTE_RSYNC_BWLIMIT=$(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --env KENOTE_RSYNC_BWLIMIT)
    if [[ -n $KENOTE_RSYNC_BWLIMIT ]]; then
      command="$command --bwlimit=$KENOTE_RSYNC_BWLIMIT"
    fi
  fi
  # 写入 tasks
  config=`cat ~/kenote_ssh/setting.json | jq -r ".tasks[$(cat ~/kenote_ssh/setting.json | jq -r ".tasks | length")]=$task"`
  echo $config | jq > ~/kenote_ssh/setting.json
  name=$(echo $task | jq -r ".name")
  # 创建对话
  tmux new -d -s "$name"
  # 发送指令
  tmux send-keys -t "$name" "clear;$command;bash $CURRENT_DIR/ssh.sh --del-task $name;exit" ENTER
  # 连接对话
  tmux a -t "$name"
  # 清理变量
  unset type command pid task config name
}

# 清理会话任务
clear_tasks() {
  list=(`cat ~/kenote_ssh/setting.json | jq -r ".tasks[].name"`)
  for name in ${list[@]}
  do
    if [[ ! -n $(tmux ls | grep "^$name:") ]]; then
      del_task $name
    fi
  done
}

# 删除会话任务
del_task() {
  # 从会话中删除
  if [[ -n $(tmux ls | grep "^$1:") ]]; then
    tmux kill-session -t "$1"
  fi
  # 写入 tasks
  config=`cat ~/kenote_ssh/setting.json | jq -r "del(.tasks[] | select(.name==\"$1\"))"`
  echo $config | jq > ~/kenote_ssh/setting.json
  # 清理变量
  unset config
}

# 获取会话任务列表
task_list() {
  if [[ -n $1 ]]; then
    list=(`cat ~/kenote_ssh/setting.json | jq -r ".tasks[] | select(.associate==\"$1\").name"`)
  else
    list=(`cat ~/kenote_ssh/setting.json | jq -r ".tasks[].name"`)
  fi
  printf "%-12s %-14s %-14s %-28s %-20s\n" "PID" "主机" "类型" "创建时间" "文件路径"
  echo "-------------------------------------------------------------------------------------------------------------------------"
  for name in ${list[@]}
  do
    node=`cat ~/kenote_ssh/setting.json | jq -r ".tasks[] | select(.name==\"$name\")"`
    type=`echo $node | jq -r ".type"`
    if (uname -s | grep -i -q "darwin"); then
      create_at=`date -r $(echo $node | jq -r ".create") "+%Y-%m-%d %H:%M:%S"`
    else
      create_at=`date -d $(echo $node | jq -r ".create") "+%Y-%m-%d %H:%M:%S"`
    fi
    host=`get_server_name "$(echo $node | jq -r ".command")"`
    file=`get_transport_file "source" "$(echo $node | jq -r ".command")"`
    printf "%-12s %-12s %-12s %-24s %-20s\n" "$name" "$host" "$type" "$create_at" "$file"
  done
}

# 会话任务操作
task_options() {
  clear_tasks
  clear
  task=`cat ~/kenote_ssh/setting.json | jq -r ".tasks[] | select(.name==\"$1\")"`
  if (uname -s | grep -i -q "darwin"); then
    create_at=`date -r $(echo $task | jq -r ".create") "+%Y-%m-%d %H:%M:%S"`
  else
    create_at=`date -d $(echo $task | jq -r ".create") "+%Y-%m-%d %H:%M:%S"`
  fi
  echo "进程任务 -- $(echo "$task" | jq -r ".name")"
  echo "------------------------"
  echo "主机: $(echo "$task" | jq -r ".associate")"
  echo "类型: $(echo "$task" | jq -r ".type")"
  echo "时间: $create_at"
  echo
  echo "指令"
  echo "-----------------------------------------------------------------------------------------------"
  echo "$(echo $task | jq -r ".command")"
  echo "-----------------------------------------------------------------------------------------------"

  echo
  echo "操作选项"
  echo "---------------------------------------------"
  echo "1. 连接进程查看           2. 删除进程任务"
  echo "---------------------------------------------"
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
    pid=`tmux ls | grep "^$1" | awk -F ":" '{print $1}'`
    if [[ $pid == $1 ]]; then
      tmux a -t $pid
      if [[ -n $(tmux ls | grep "^$1") ]]; then
        task_options $1 $2
        return
      fi
    else
      echo
      echo "- 进程任务已被删除"
      echo
      read  -n1 -p "按任意键继续" key
    fi
    del_task "$1"
    clear
    show_menu "" $2
  ;;
  2)
    clear
    confirm "确定要删除进程任务 - [$1] 吗?" "n"
    if [[ $? == 0 ]]; then
      del_task "$1"
    fi
    if [[ -n $(tmux ls | grep "^$1") ]]; then
      task_options $1 $2
    else
      echo
      echo "- 进程任务已被删除"
      echo
      read -n1 -p "按任意键继续" 
      clear
      show_menu "" $2
    fi
  ;;
  0)
    clear
    show_menu "" $2
  ;;
  *)
    clear
    task_options $1 $2 "请输入正确的数字"
  ;;
  esac
  unset task create_at sub_choice
}
