#! /bin/bash

# 获取远端 x-ui 配置
get_xui_inbounds() {
  if [[ $1 == 'local' ]]; then
    inbound=$(cat /usr/local/x-ui/bin/config.json  | jq -r '[.inbounds[] | select(.protocol|test("^vmess$"))][0]')
  else
    inbound=$(ssh $1 cat /usr/local/x-ui/bin/config.json  | jq -r '[.inbounds[] | select(.protocol|test("^vmess$"))][0]')
  fi
  if [[ ! -n $(echo $inbound | jq) ]]; then
    return
  fi
  json="{}"
  json=$(echo $json | jq -r ".name=\"$1\"")
  json=$(echo $json | jq -r ".server=\"$2\"")
  if [[ -n $3 ]]; then
    json=$(echo $json | jq -r ".port=$3")
  else
    json=$(echo $json | jq -r ".port=$(echo $inbound | jq -r '.port')")
  fi
  json=$(echo $json | jq -r ".type=\"$(echo $inbound | jq -r '.protocol')\"")
  json=$(echo $json | jq -r ".uuid=\"$(echo $inbound | jq -r '.settings.clients[0].id')\"")
  json=$(echo $json | jq -r ".alterId=$(echo $inbound | jq -r '.settings.clients[0].alterId')")
  json=$(echo $json | jq -r ".cipher=\"auto\"")
  if [[ -n $4 || $(echo $json | jq -r '.port') == 443 ]]; then
    json=$(echo $json | jq -r ".tls=true")
    json=$(echo $json | jq -r ".[\"skip-cert-verify\"]=false")
  fi
  json=$(echo $json | jq -r ".network=\"$(echo $inbound | jq -r '.streamSettings.network')\"")
  json=$(echo $json | jq -r ".udp=true")
  if [[ -n $(echo $inbound | jq -r '.streamSettings.network' | grep -iE "^ws$") ]]; then
    json=$(echo $json | jq -r ".[\"ws-opts\"].path=\"$(echo $inbound | jq -r '.streamSettings.wsSettings.path')\"")
    json=$(echo $json | jq -r ".[\"ws-opts\"].headers.Host=\"$2\"")
  fi
  echo $json
  unset inbound json
}

# 转换 clash 配置文件
to_clash_file() {
  json=$(curl -Lso- $(cat $1 | jq -r '.template') | yq eval -o json | jq -r '.proxies=[]')
  # proxies
  for name in $(cat $1 | jq -r '.proxies[].name'); do
    proxy=$(cat $1 | jq -r "[.proxies[] | select(.name|test(\"^$name$\"))][0]")
    server=$(echo $proxy | jq -r '.server')
    port=$(echo $proxy | jq -r '.port')
    tls=$(echo $proxy | jq -r '.tls')
    index=$(echo $json | jq -r '.proxies | length')
    inbound=$(get_xui_inbounds $name $server "$port" $tls)
    if [[ ! -n $(echo $inbound | jq) ]]; then
      continue
    fi
    if [[ -n $(echo $proxy | jq -r '.tagname') ]]; then
      inbound=$(echo $inbound | jq -r ".name=\"$(echo $proxy | jq -r '.tagname')\"")
    fi
    json=$(echo $json | jq -r ".proxies[$index]=$inbound")
    unset proxy server port tls index inbound
  done
  # proxy-groups
  for n in $(seq 1 $(echo $json | jq -r '.["proxy-groups"] | length')); do
    if [[ -n $(echo $json | jq -r ".[\"proxy-groups\"][$((n-1))] | select(.name|test(\"广告拦截|运营劫持|国内媒体|全球直连|全球拦截\"))") ]]; then
      continue
    fi
    for i in $(seq 1 $(echo $json | jq -r '.proxies | length')); do
      json="$(jq -r ".[\"proxy-groups\"][$((n-1))].proxies += [\"$(echo $json | jq -r ".proxies[$((i-1))].name")\"]" <<< "$json")"
    done
  done
  # generate yaml
  echo "# -- $(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --info utc) --"
  echo $json | yq eval -P
  unset json
}

# 转换 QuantumultX 配置文件
to_quantumultx_file() {
  echo -e "# QuantumultX -- $(curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --info utc)"
  # proxies
  for name in $(cat $1 | jq -r '.proxies[].name'); do
    proxy=$(cat $1 | jq -r "[.proxies[] | select(.name|test(\"^$name$\"))][0]")
    server=$(echo $proxy | jq -r '.server')
    port=$(echo $proxy | jq -r '.port')
    tls=$(echo $proxy | jq -r '.tls')
    inbound=$(get_xui_inbounds $name $server "$port" $tls)
    if [[ ! -n $(echo $inbound | jq) ]]; then
      continue
    fi
    if [[ -n $(echo $proxy | jq -r '.tagname') ]]; then
      inbound=$(echo $inbound | jq -r ".name=\"$(echo $proxy | jq -r '.tagname')\"")
    fi
    json="[]"
    json="$(jq -r ". += [\"$(echo $inbound | jq -r '.type')=$server:$port\"]" <<< "$json")"
    json="$(jq -r ". += [\"method=chacha20-ietf-poly1305\"]" <<< "$json")"
    json="$(jq -r ". += [\"password=$(echo $inbound | jq -r '.uuid')\"]" <<< "$json")"
    if [[ -n $(echo $inbound | jq -r '.tls') ]]; then
      json="$(jq -r ". += [\"tls-verification=false\"]" <<< "$json")"
      json="$(jq -r ". += [\"obfs=$(echo $inbound | jq -r '.network')s\"]" <<< "$json")"
    else
      json="$(jq -r ". += [\"obfs=$(echo $inbound | jq -r '.network')\"]" <<< "$json")"
    fi
    obfs_uri=$(echo $inbound | jq -r ".[\"ws-opts\"].path" )
    json="$(jq -r ". += [\"obfs-uri=$obfs_uri\"]" <<< "$json")"
    json="$(jq -r ". += [\"fast-open=false\"]" <<< "$json")"
    json="$(jq -r ". += [\"udp-relay=true\"]" <<< "$json")"
    json="$(jq -r ". += [\"aead=true\"]" <<< "$json")"
    json="$(jq -r ". += [\"tag=$(echo $inbound | jq -r ".name")\"]" <<< "$json")"
    for n in $(seq 1 $(echo $json | jq -r '. | length')); do
      if [[ $n -gt 1 ]]; then
        line+=", "
      fi
      line+=$(echo $json | jq -r ".[$((n-1))]")
    done
    echo -e $line
    unset proxy server port tls index inbound obfs_uri line
  done
}

# 获取配置文件路径
get_config_file() {
  if [[ -n $(echo "$1" | gawk '/^(\/)[^/s]*/{print $0}') ]]; then
    echo "$1"
  else
    echo $(pwd)/$(echo "$1" | sed -E 's/^(\.\/)//')
  fi
}

curl -Lso- $KENOTE_BASH_MIRROR/base.sh | bash -s -- --install jq yq
case "$1" in
--clash)
  xui_file=$(get_config_file "$2")
  if [[ ! -f $xui_file ]]; then
    echo
    echo "- 未找到配置文件"
    echo
    exit 0
  fi
  to_clash_file $xui_file
;;
--qx | --quantumultx)
  xui_file=$(get_config_file "$2")
  if [[ ! -f $xui_file ]]; then
    echo
    echo "- 未找到配置文件"
    echo
    exit 0
  fi
  to_quantumultx_file $xui_file
;;
*)
  clear
  echo
  echo -e "# 创建 x-ui.json"
  echo
  echo -e "{"
  echo -e "  \"template\": \"https://mirrors.kenote.site/kenote/bash/clash/config.yml\","
  echo -e "  \"proxies\": ["
  echo -e "    {"
  echo -e "      \"name\": \"SSH 连接名称\","
  echo -e "      \"server\": \"服务器域名\","
  echo -e "      \"port\": 443,"
  echo -e "      \"tagname\": \"节点显示名称\","
  echo -e "    }"
  echo -e "  ]"
  echo -e "}"
  echo
  echo -e "# 生成 Clash 配置"
  echo -e "curl -Lso- \$KENOTE_BASH_MIRROR/clash/core.sh | bash -s -- --clash x-ui.json | tee kenote.yml"
  echo
  echo -e "# 生成 QuantumultX 配置"
  echo -e "curl -Lso- \$KENOTE_BASH_MIRROR/clash/core.sh | bash -s -- --qx x-ui.json | tee kenote.snippet"
  echo
;;
esac