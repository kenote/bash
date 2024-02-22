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
# 或
export KENOTE_BASH_MIRROR=https://raw.githubusercontent.com/kenote/bash/main
```

Gitee
```bash
curl -Lso- https://gitee.com/kenote/bash/raw/main/base.sh | bash -s -- --mirror https://gitee.com/kenote/bash/raw/main
# 或
export KENOTE_BASH_MIRROR=https://gitee.com/kenote/bash/raw/main
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

设置热键
```bash
curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --hotkey "kn"; \
if (echo $SHELL | grep -q "zsh");then source ~/.zshrc; else source ~/.bash_profile; fi
```

## 自定义源

拉取 Github; 默认 `/mnt/mirrors`, 也可以通过 `--install /home/mirrors` 指定
```bash
curl -Lso- https://raw.githubusercontent.com/kenote/bash/main/base.sh | bash -s -- --install
```

Nginx 设置
```nginx
location /kenote {
    alias /mnt/mirrors/kenote;
    index index.html index.htm;

    autoindex on;
    charset utf-8;

    types {
        text/plain  txt md sh conf repo json yml yaml tpl njk mjml php;
    }
}
location /packages {
    alias /mnt/mirrors/packages;
    index index.html index.htm;

    autoindex on;
    charset utf-8;

    types {
        text/plain  txt md sh conf repo json yml yaml tpl njk mjml php;
    }
}
```

添加计划任务
```bash
/mnt/mirrors/kenote.sh --cron
```

设定计划任务更新点
```bash
/mnt/mirrors/kenote.sh --cron "30 2 * * *"
```

手动更新
```bash
/mnt/mirrors/kenote.sh --update
```