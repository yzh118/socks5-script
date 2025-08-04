#!/bin/bash

set -e

# 彩色输出
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 安装目录
INSTALL_DIR="/usr/local/bin"
CONFIG_FILE="/usr/local/bin/singbox_socks5.json"
PAN_URL="https://nfd.s-u.top/parser?url=https://share.feijipan.com/s/s1OAqSwZ"

# 检测系统中是否已安装 Sing-box
detect_singbox() {
    local found_paths=()
    
    # 搜索常见的 singbox 可执行文件位置
    local search_paths=(
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/opt"
        "/root"
        "/home/*"
    )
    
    local search_names=("singbox" "sing-box" "sing-box")
    
    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            for name in "${search_names[@]}"; do
                # 使用 find 命令搜索，不区分大小写
                local found=$(find "$path" -maxdepth 2 -type f -executable -iname "$name" 2>/dev/null | head -n1)
                if [ -n "$found" ] && [ -f "$found" ]; then
                    found_paths+=("$found")
                fi
            done
        fi
    done
    
    # 返回找到的第一个有效路径
    if [ ${#found_paths[@]} -gt 0 ]; then
        echo "${found_paths[0]}"
        return 0
    else
        echo ""
        return 1
    fi
}

# 测试 Sing-box 是否可用
test_singbox() {
    local singbox_path="$1"
    if [ -z "$singbox_path" ] || [ ! -f "$singbox_path" ]; then
        return 1
    fi
    
    # 测试版本信息
    local version_output=$("$singbox_path" version 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$version_output" ]; then
        echo "$version_output"
        return 0
    else
        return 1
    fi
}

# 依赖检测与安装
deps=(wget curl tar openssl)
install_deps() {
    for dep in "${deps[@]}"; do
        if ! command -v $dep &>/dev/null; then
            echo -e "${BLUE}安装依赖: $dep${NC}"
            if command -v apt-get &>/dev/null; then
                apt-get update && apt-get install -y $dep
            elif command -v yum &>/dev/null; then
                yum install -y $dep
            else
                echo -e "${RED}不支持的系统，无法自动安装依赖${NC}"; exit 1
            fi
        fi
    done
}

show_menu() {
    clear
    echo "=================================="
    echo -e "${RED}Socks5 一键安装脚本${NC}"
    echo -e "${GREEN}原作者:${NC} 1118luntan.top"
    echo -e "${GREEN}Telegram 频道${NC}: https://t.me/a1118luntan"
    echo -e "${GREEN}Telegram 群组${NC}: https://t.me/one118lt"
    echo -e "${GREEN}YouTube 频道${NC}: https://www.youtube.com/@1118luntan"
    echo "=================================="
    echo ""
    echo -e " ${GREEN}1.${NC} 安装"
    echo -e " ${GREEN}2.${NC} ${RED}卸载${NC}"
    echo " -------------"
    echo -e " ${GREEN}3.${NC} 关闭、开启、重启"
    echo -e " ${GREEN}4.${NC} 修改配置"
    echo -e " ${GREEN}5.${NC} 显示配置"
    echo " -------------"
    echo -e " ${GREEN}6.${NC} 更新 Singbox 内核"
    echo -e " ${GREEN}7.${NC} 检查服务状态"
    echo " -------------"
    echo -e " ${GREEN}0.${NC} 退出"
    echo ""
    read -rp "请输入选项 [0-7]: " menuInput
}

install_singbox() {
    # 检测系统架构
    arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv7" ;;
        *) echo -e "${RED}不支持的架构: $arch${NC}"; exit 1 ;;
    esac
    
    # 检测是否已安装 Sing-box
    local existing_singbox=$(detect_singbox)
    if [ -n "$existing_singbox" ]; then
        echo -e "${YELLOW}检测到已安装的 Sing-box: $existing_singbox${NC}"
        local version_info=$(test_singbox "$existing_singbox")
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Sing-box 版本信息: $version_info${NC}"
            echo -e "${BLUE}请选择安装方式：${NC}"
            echo "1. 使用现有 Sing-box（跳过下载）"
            echo "2. 重新下载安装"
            read -rp "请输入选择 [1/2]: " use_existing
            if [[ "$use_existing" == "1" ]]; then
                echo -e "${GREEN}使用现有 Sing-box: $existing_singbox${NC}"
                # 创建软链接到标准位置
                ln -sf "$existing_singbox" "$INSTALL_DIR/singbox"
                echo -e "${GREEN}Sing-box 配置完成: $INSTALL_DIR/singbox${NC}"
                return 0
            fi
        else
            echo -e "${RED}现有 Sing-box 无法正常使用，将重新下载安装${NC}"
        fi
    fi
    
    # 下载并安装 Sing-box
    tmpdir=$(mktemp -d)
    cd "$tmpdir"
    if [[ "$src_choice" == "2" ]]; then
        echo -e "${BLUE}使用国内网盘安装包...${NC}"
        wget -O singbox.tar.gz "$PAN_URL"
    elif [[ "$src_choice" == "3" ]]; then
        if [[ -z "$custom_url" ]]; then
            echo -e "${RED}自定义URL不能为空${NC}"; exit 1
        fi
        echo -e "${BLUE}使用自定义URL下载安装包...${NC}"
        wget -O singbox.tar.gz "$custom_url"
    else
        echo -e "${BLUE}获取最新 Sing-box 版本...${NC}"
        tag=$(curl -sL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep tag_name | grep -E -o 'v([0-9.]+)')
        if [[ -z "$tag" ]]; then echo -e "${RED}获取版本失败${NC}"; exit 1; fi
        asset_json=$(curl -sL "https://api.github.com/repos/SagerNet/sing-box/releases/latest")
        asset_name=$(echo "$asset_json" | grep -oE '"name":\s*"[^\"]*linux[^\"]*'"$arch"'[^\"]*tar.gz"' | head -n1 | awk -F '"' '{print $4}')
        if [[ -z "$asset_name" ]]; then echo -e "${RED}未找到官方包${NC}"; exit 1; fi
        url="https://github.com/SagerNet/sing-box/releases/download/$tag/$asset_name"
        wget -O singbox.tar.gz "$url"
    fi
    tar zxf singbox.tar.gz
    # 自动查找解压目录并复制可执行文件
    singbox_dir=$(find . -maxdepth 1 -type d -name 'sing-box-*' | head -n1)
    # 适配新版和老版可执行文件名
    if [[ -f "$singbox_dir/sing-box" ]]; then
        cp "$singbox_dir/sing-box" "$INSTALL_DIR/singbox"
    elif [[ -f "$singbox_dir/singbox" ]]; then
        cp "$singbox_dir/singbox" "$INSTALL_DIR/singbox"
    else
        echo -e "${RED}未找到 singbox 可执行文件${NC}"; exit 1
    fi
    chmod +x "$INSTALL_DIR/singbox"
    cd /
    rm -rf "$tmpdir"
    echo -e "${GREEN}Sing-box 安装完成: $INSTALL_DIR/singbox${NC}"
}

# 生成 Socks5 配置
gen_socks5_config() {
    echo -e "${GREEN}请输入入口端口 [默认: 10808]:${NC}"
    read -rp "端口: " port; port=${port:-10808}
    echo -e "${GREEN}是否启用用户名密码认证？[y/N]:${NC}"
    read -rp "选择: " auth
    if [[ "$auth" =~ ^[Yy]$ ]]; then
        read -rp "用户名 [user]: " user; user=${user:-user}
        pw=$(openssl rand -base64 8)
        read -rp "密码 [$pw]: " input_pw; pw=${input_pw:-$pw}
    fi
    
    # 询问是否启用多组端口映射
    echo -e "${GREEN}是否启用多组端口映射？[y/N]:${NC}"
    echo "多组端口映射：可以配置多组映射规则，每组包含入口端口和出口IP"
    read -rp "选择: " enable_mapping
    if [[ "$enable_mapping" =~ ^[Yy]$ ]]; then
        gen_one_to_one_config "$port" "$auth" "$user" "$pw"
    else
        gen_basic_config "$port" "$auth" "$user" "$pw"
    fi
}

# 生成基础配置
gen_basic_config() {
    local port="$1"
    local auth="$2"
    local user="$3"
    local pw="$4"
    
    if [[ "$auth" =~ ^[Yy]$ ]]; then
        cat > "$CONFIG_FILE" <<EOF
{
  "log": {"level": "info"},
  "inbounds": [{
    "type": "socks",
    "listen": "0.0.0.0",
    "listen_port": $port,
    "users": [{"username": "$user", "password": "$pw"}]
  }],
  "outbounds": [{"type": "direct"}]
}
EOF
        echo -e "\n${GREEN}已生成带认证的 Socks5 配置：$user/$pw${NC}"
    else
        cat > "$CONFIG_FILE" <<EOF
{
  "log": {"level": "info"},
  "inbounds": [{
    "type": "socks",
    "listen": "0.0.0.0",
    "listen_port": $port
  }],
  "outbounds": [{"type": "direct"}]
}
EOF
        echo -e "\n${GREEN}已生成匿名 Socks5 配置${NC}"
    fi
}

# 生成多组映射配置
gen_one_to_one_config() {
    local base_port="$1"
    local auth="$2"
    local user="$3"
    local pw="$4"
    
    echo -e "${BLUE}配置多组端口映射：${NC}"
    echo "可以配置多组映射规则，每组包含入口端口和出口IP"
    echo ""
    
    # 收集映射规则
    local mappings=()
    local current_port=$base_port
    
    while true; do
        echo -e "${YELLOW}=== 配置第 $(( ${#mappings[@]} + 1 )) 组映射 ===${NC}"
        echo ""
        
        # 设置入口端口
        echo -e "${BLUE}设置入口端口：${NC}"
        read -rp "入口端口 [$current_port]: " input_port
        if [ -n "$input_port" ]; then
            current_port=$input_port
        fi
        
        # 验证端口
        if ! [[ "$current_port" =~ ^[0-9]+$ ]] || [ "$current_port" -lt 1 ] || [ "$current_port" -gt 65535 ]; then
            echo -e "${RED}✗ 端口格式错误，请输入1-65535之间的数字${NC}"
            continue
        fi
        
        # 检查端口是否已被使用
        for mapping in "${mappings[@]}"; do
            IFS='|' read -ra parts <<< "$mapping"
            if [ "${parts[0]}" = "$current_port" ]; then
                echo -e "${RED}✗ 端口 $current_port 已被使用${NC}"
                continue 2
            fi
        done
        
        echo ""
        echo -e "${BLUE}设置出口IP：${NC}"
        echo "1. 使用默认出口IP（本机公网IP）"
        echo "2. 指定出口IP"
        read -rp "请选择 [1-2]: " outbound_type
        
        case $outbound_type in
            1)
                # 使用默认出口IP
                mappings+=("$current_port|default")
                echo -e "${GREEN}✓ 映射组 $(( ${#mappings[@]} )) 配置完成：${NC}"
                echo -e "${GREEN}  入口端口 $current_port → 默认出口IP${NC}"
                ;;
            2)
                # 指定出口IP
                read -rp "出口IP地址: " outbound_ip
                
                # 验证IP格式
                if [[ "$outbound_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    # 检查IP格式
                    local IFS='.' read -ra ip_parts <<< "$outbound_ip"
                    local valid_ip=true
                    for part in "${ip_parts[@]}"; do
                        if [ "$part" -lt 0 ] || [ "$part" -gt 255 ]; then
                            valid_ip=false
                            break
                        fi
                    done
                    
                    if [ "$valid_ip" = true ]; then
                        mappings+=("$current_port|custom|$outbound_ip")
                        echo -e "${GREEN}✓ 映射组 $(( ${#mappings[@]} )) 配置完成：${NC}"
                        echo -e "${GREEN}  入口端口 $current_port → 出口IP $outbound_ip${NC}"
                    else
                        echo -e "${RED}✗ IP地址格式错误${NC}"
                        continue
                    fi
                else
                    echo -e "${RED}✗ 请输入有效的IP地址${NC}"
                    continue
                fi
                ;;
            *)
                echo -e "${RED}无效选择，请输入1-2${NC}"
                continue
                ;;
        esac
        
        # 自动递增端口号
        ((current_port++))
        
        echo ""
        echo -e "${BLUE}当前已配置的映射组：${NC}"
        for i in "${!mappings[@]}"; do
            IFS='|' read -ra parts <<< "${mappings[$i]}"
            local port="${parts[0]}"
            local type="${parts[1]}"
            if [ "$type" = "default" ]; then
                echo -e "${GREEN}  组 $((i+1)): 入口端口 $port → 默认出口IP${NC}"
            elif [ "$type" = "custom" ]; then
                local outbound_ip="${parts[2]}"
                echo -e "${GREEN}  组 $((i+1)): 入口端口 $port → 出口IP $outbound_ip${NC}"
            fi
        done
        echo ""
        
        # 询问是否继续添加
        echo -e "${YELLOW}是否继续添加新的映射组？[Y/n]:${NC}"
        read -rp "选择: " continue_add
        if [[ "$continue_add" =~ ^[Nn]$ ]]; then
            break
        fi
    done
    
    # 检查是否至少配置了一组
    if [ ${#mappings[@]} -eq 0 ]; then
        echo -e "${RED}至少需要配置一组映射${NC}"
        return 1
    fi
    
    # 生成配置文件
    generate_mapping_config "$auth" "$user" "$pw" "${mappings[@]}"
}





# 生成映射配置文件
generate_mapping_config() {
    local auth="$1"
    local user="$2"
    local pw="$3"
    shift 3
    local mappings=("$@")
    
    local auth_config=""
    if [[ "$auth" =~ ^[Yy]$ ]]; then
        auth_config=", \"users\": [{\"username\": \"$user\", \"password\": \"$pw\"}]"
    fi
    
    # 构建入站配置
    local inbounds=""
    local rules=""
    local outbounds='{"type": "direct", "tag": "direct-out"}'
    
    for mapping in "${mappings[@]}"; do
        IFS='|' read -ra parts <<< "$mapping"
        local port="${parts[0]}"
        local type="${parts[1]}"
        
        # 添加入站
        inbounds="$inbounds,
    {
      \"type\": \"socks\",
      \"listen\": \"0.0.0.0\",
      \"listen_port\": $port,
      \"tag\": \"socks-$port\"$auth_config
    }"
        
        # 添加规则
        if [ "$type" = "default" ]; then
            # 使用默认出口IP（本机公网IP）
            rules="$rules,
      {
        \"inbound\": [\"socks-$port\"],
        \"outbound\": \"direct-out\"
      }"
        elif [ "$type" = "custom" ]; then
            # 使用指定出口IP
            local outbound_ip="${parts[2]}"
            local custom_tag="custom-$port"
            
            # 添加自定义出口
            outbounds="$outbounds,
    {
      \"type\": \"direct\",
      \"tag\": \"$custom_tag\",
      \"bind_interface\": \"$outbound_ip\"
    }"
            
            # 添加规则
            rules="$rules,
      {
        \"inbound\": [\"socks-$port\"],
        \"outbound\": \"$custom_tag\"
      }"
        fi
    done
    
    # 移除开头的逗号
    inbounds="${inbounds#,}"
    rules="${rules#,}"
    
    cat > "$CONFIG_FILE" <<EOF
{
  "log": {"level": "info"},
  "inbounds": [$inbounds],
  "outbounds": [$outbounds],
  "routing": {
    "rules": [$rules]
  }
}
EOF
    
    echo -e "\n${GREEN}✓ 多组端口映射配置完成！${NC}"
    echo ""
    echo -e "${BLUE}=== 配置摘要 ===${NC}"
    echo -e "${GREEN}共配置了 ${#mappings[@]} 组映射：${NC}"
    echo ""
    for i in "${!mappings[@]}"; do
        IFS='|' read -ra parts <<< "${mappings[$i]}"
        local port="${parts[0]}"
        local type="${parts[1]}"
        if [ "$type" = "default" ]; then
            echo -e "${GREEN}  组 $((i+1)): 入口端口 $port → 默认出口IP${NC}"
        elif [ "$type" = "custom" ]; then
            local outbound_ip="${parts[2]}"
            echo -e "${GREEN}  组 $((i+1)): 入口端口 $port → 出口IP $outbound_ip${NC}"
        fi
    done
    echo ""
}



# 启动 Sing-box Socks5 服务
start_singbox() {
    # 先检查是否已有进程在运行
    if pgrep -f "singbox" > /dev/null; then
        echo -e "${YELLOW}检测到singbox进程正在运行，先停止现有进程...${NC}"
        pkill -f "singbox" 2>/dev/null || true
        sleep 2
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}配置文件不存在: $CONFIG_FILE${NC}"
        return 1
    fi
    
    # 检查可执行文件是否存在
    if [ ! -f "$INSTALL_DIR/singbox" ]; then
        echo -e "${RED}singbox可执行文件不存在: $INSTALL_DIR/singbox${NC}"
        return 1
    fi
    
    # 启动服务
    nohup "$INSTALL_DIR/singbox" run -c "$CONFIG_FILE" >/dev/null 2>&1 &
    sleep 2
    
    # 检查是否启动成功
    if pgrep -f "singbox" > /dev/null; then
        echo -e "\n${GREEN}✓ Socks5 服务已启动！${NC}"
        echo ""
        echo -e "${BLUE}=== 连接信息 ===${NC}"
        
        # 显示端口信息
        ports=$(grep 'listen_port' "$CONFIG_FILE" 2>/dev/null | grep -o '[0-9]*' | tr '\n' ' ')
        if [ -n "$ports" ]; then
            echo -e "${GREEN}  监听端口: $ports${NC}"
        fi
        
        # 显示认证信息
        if grep -q 'users' "$CONFIG_FILE"; then
            username=$(grep 'username' "$CONFIG_FILE" 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
            password=$(grep 'password' "$CONFIG_FILE" 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
            echo -e "${GREEN}  认证模式: 用户名/密码${NC}"
            echo -e "${GREEN}  用户名: $username${NC}"
            echo -e "${GREEN}  密码: $password${NC}"
        else
            echo -e "${GREEN}  认证模式: 无需认证${NC}"
        fi
        echo -e "\n进程信息："
        ps aux | grep singbox | grep -v grep
    else
        echo -e "${RED}服务启动失败，请检查配置文件和权限${NC}"
        return 1
    fi
}

# 菜单主循环
while true; do
    show_menu
    case $menuInput in
        1)
            install_deps
            # 选择安装源
            echo -e "${GREEN}请选择 Sing-box 安装源：${NC}"
            echo "1. 官方GitHub（国外服务器推荐，需能访问github.com）"
            echo "2. 国内网盘（国内服务器推荐，速度快）"
            echo "3. 自定义URL（手动输入下载链接）"
            read -rp "请输入数字 [1/2/3]: " src_choice
            if [[ "$src_choice" == "3" ]]; then
                read -rp "请输入Sing-box安装包的下载URL: " custom_url
            fi
            install_singbox
            gen_socks5_config
            start_singbox
            read -n1 -s -r -p "按任意键返回菜单..."
            ;;
        2)
            echo -e "${RED}即将卸载 Sing-box 及配置...${NC}"
            
            # 检查是否有singbox进程在运行
            if pgrep -f "singbox" > /dev/null; then
                echo -e "${YELLOW}检测到singbox进程正在运行，正在停止...${NC}"
                pkill -f "singbox" 2>/dev/null || true
                sleep 2
                
                # 强制杀死残留进程
                if pgrep -f "singbox" > /dev/null; then
                    echo -e "${YELLOW}强制停止残留进程...${NC}"
                    pkill -9 -f "singbox" 2>/dev/null || true
                fi
            fi
            
            # 删除文件和配置
            rm -f "$INSTALL_DIR/singbox" "$CONFIG_FILE" 2>/dev/null || true
            
            # 检查是否还有其他singbox相关文件
            if [ -f "$INSTALL_DIR/singbox" ]; then
                echo -e "${YELLOW}删除singbox可执行文件...${NC}"
                rm -f "$INSTALL_DIR/singbox"
            fi
            
            if [ -f "$CONFIG_FILE" ]; then
                echo -e "${YELLOW}删除配置文件...${NC}"
                rm -f "$CONFIG_FILE"
            fi
            
            # 最终检查
            if pgrep -f "singbox" > /dev/null; then
                echo -e "${RED}警告：仍有singbox进程在运行，请手动检查${NC}"
                ps aux | grep singbox | grep -v grep
            else
                echo -e "${GREEN}所有singbox进程已停止${NC}"
            fi
            
            echo -e "${GREEN}卸载完成${NC}"
            read -n1 -s -r -p "按任意键返回菜单..."
            ;;
        3)
            echo -e "${GREEN}1. 启动\n2. 关闭\n3. 重启${NC}"
            read -rp "请选择操作: " act
            if [[ "$act" == "1" ]]; then
                start_singbox
            elif [[ "$act" == "2" ]]; then
                if pgrep -f "singbox" > /dev/null; then
                    echo -e "${YELLOW}正在停止singbox进程...${NC}"
                    pkill -f "singbox" 2>/dev/null || true
                    sleep 2
                    
                    # 检查是否还有残留进程
                    if pgrep -f "singbox" > /dev/null; then
                        echo -e "${YELLOW}强制停止残留进程...${NC}"
                        pkill -9 -f "singbox" 2>/dev/null || true
                    fi
                    
                    if pgrep -f "singbox" > /dev/null; then
                        echo -e "${RED}仍有进程在运行，请手动检查${NC}"
                        ps aux | grep singbox | grep -v grep
                    else
                        echo -e "${GREEN}已关闭${NC}"
                    fi
                else
                    echo -e "${YELLOW}没有检测到singbox进程在运行${NC}"
                fi
            elif [[ "$act" == "3" ]]; then
                echo -e "${YELLOW}正在重启服务...${NC}"
                pkill -f "singbox" 2>/dev/null || true
                sleep 2
                start_singbox
            else
                echo "无效选项"
            fi
            read -n1 -s -r -p "按任意键返回菜单..."
            ;;
        4)
            echo -e "${GREEN}修改配置（将重新生成 Socks5 配置）${NC}"
            gen_socks5_config
            read -n1 -s -r -p "按任意键返回菜单..."
            ;;
        5)
            echo -e "${GREEN}当前 Socks5 配置如下：${NC}"
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            else
                echo "未找到配置文件: $CONFIG_FILE"
            fi
            read -n1 -s -r -p "按任意键返回菜单..."
            ;;
        6)
            echo -e "${GREEN}更新 Sing-box 内核...${NC}"
            pkill -f 'singbox run' 2>/dev/null || true
            install_singbox
            echo -e "${GREEN}Sing-box 已更新${NC}"
            read -n1 -s -r -p "按任意键返回菜单..."
            ;;
        7)
            echo -e "${BLUE}=== 服务状态检查 ===${NC}"
            echo ""
            
            # 检查进程
            if pgrep -f "singbox" > /dev/null; then
                echo -e "${GREEN}✓ singbox进程正在运行${NC}"
                echo -e "${BLUE}进程信息：${NC}"
                ps aux | grep singbox | grep -v grep
            else
                echo -e "${RED}✗ 没有检测到singbox进程${NC}"
            fi
            
            echo ""
            # 检查文件
            if [ -f "$INSTALL_DIR/singbox" ]; then
                echo -e "${GREEN}✓ singbox可执行文件存在: $INSTALL_DIR/singbox${NC}"
            else
                echo -e "${RED}✗ singbox可执行文件不存在${NC}"
            fi
            
            if [ -f "$CONFIG_FILE" ]; then
                echo -e "${GREEN}✓ 配置文件存在: $CONFIG_FILE${NC}"
                echo -e "${BLUE}配置摘要：${NC}"
                # 显示端口配置
                ports=$(grep 'listen_port' "$CONFIG_FILE" 2>/dev/null | grep -o '[0-9]*' | tr '\n' ' ')
                if [ -n "$ports" ]; then
                    echo "  监听端口: $ports"
                else
                    echo "  未找到端口配置"
                fi
                
                # 显示认证信息
                if grep -q 'users' "$CONFIG_FILE" 2>/dev/null; then
                    username=$(grep 'username' "$CONFIG_FILE" 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')
                    echo "  认证模式: 用户名/密码"
                    echo "  用户名: $username"
                else
                    echo "  认证模式: 无需认证"
                fi
            else
                echo -e "${RED}✗ 配置文件不存在${NC}"
            fi
            
            echo ""
            # 检查端口
            if pgrep -f "singbox" > /dev/null; then
                echo -e "${BLUE}端口使用情况：${NC}"
                netstat -tlnp 2>/dev/null | grep singbox || echo "未找到端口信息"
            fi
            
            read -n1 -s -r -p "按任意键返回菜单..."
            ;;
        0)
            echo "退出。"
            exit 0
            ;;
        *)
            echo "无效选项"; sleep 1
            ;;
    esac
done
