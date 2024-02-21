# Bash

```bash
_  _ ____ _  _ ____ ___ ____  
|_/  |___ |\ | |  |  |  |___  
| \_ |___ | \| |__|  |  |___  

Bash脚本工具 v.1.0
```

## 设置源

Github
```bash
curl -Lso- https://raw.githubusercontent.com/kenote/bash/main/base.sh | bash -s -- --mirror https://raw.githubusercontent.com/kenote/bash/main
echo $SHELL | grep -q "zsh" && source ~/.zshrc
```

Gitee
```bash
curl -Lso- https://gitee.com/kenote/bash/raw/main/base.sh | bash -s -- --mirror https://gitee.com/kenote/bash/raw/main
echo $SHELL | grep -q "zsh" && source ~/.zshrc
```

## Install 安装

安装脚本
```bash
curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --init
```

运行
```bash
~/kenote/start.sh
```