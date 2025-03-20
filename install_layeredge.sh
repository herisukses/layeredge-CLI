#!/bin/bash

# LayerEdge CLI Light Node 一键安装脚本
# 此脚本将自动安装并配置LayerEdge CLI Light Node

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}[STEP]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

# 检查并安装依赖
install_dependencies() {
    log_step "检查并安装系统依赖"
    
    # 更新包列表
    log_info "更新包列表..."
    apt-get update -y || { log_error "无法更新包列表"; exit 1; }
    
    # 安装基本工具
    log_info "安装基本工具..."
    apt-get install -y curl wget git build-essential pkg-config libssl-dev || { log_error "安装基本工具失败"; exit 1; }
    
    # 检查并安装Go
    if ! check_command go; then
        log_info "安装Go..."
        wget https://go.dev/dl/go1.20.linux-amd64.tar.gz -O go.tar.gz || { log_error "下载Go失败"; exit 1; }
        rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz || { log_error "解压Go失败"; exit 1; }
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.profile
        source $HOME/.profile
        rm go.tar.gz
        log_info "Go安装完成: $(go version)"
    else
        log_info "Go已安装: $(go version)"
    fi
    
    # 检查并安装Rust
    if ! check_command rustc; then
        log_info "安装Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || { log_error "安装Rust失败"; exit 1; }
        source $HOME/.cargo/env
        log_info "Rust安装完成: $(rustc --version)"
    else
        log_info "Rust已安装: $(rustc --version)"
    fi
    
    # 安装Risc0工具链
    log_info "安装Risc0工具链..."
    curl -L https://risczero.com/install | bash || { log_error "安装Risc0脚本下载失败"; exit 1; }
    
    # 确保rzup命令在PATH中
    export PATH="$HOME/.risc0/bin:$PATH"
    
    # 加载环境变量
    if [ -f "$HOME/.bashrc" ]; then
        source $HOME/.bashrc
    fi
    if [ -f "$HOME/.cargo/env" ]; then
        source $HOME/.cargo/env
    fi
    
    # 安装risc0工具链
    if ! check_command rzup; then
        log_error "rzup命令未找到，请确保安装脚本正确执行"
        log_info "尝试手动安装risc0工具链..."
        if [ -f "$HOME/.risc0/bin/rzup" ]; then
            $HOME/.risc0/bin/rzup install || { log_error "Risc0工具链安装失败"; exit 1; }
        else
            log_error "找不到rzup工具，Risc0安装失败"; exit 1;
        fi
    else
        log_info "执行rzup install..."
        rzup install || { log_error "Risc0工具链安装失败"; exit 1; }
    fi
    
    # 设置risc0环境变量
    export RISC0_TOOLCHAIN_PATH="$HOME/.risc0/toolchain"
    echo 'export PATH="$HOME/.risc0/bin:$PATH"' >> $HOME/.profile
    echo 'export RISC0_TOOLCHAIN_PATH="$HOME/.risc0/toolchain"' >> $HOME/.profile
    
    log_info "所有依赖安装完成"
}

# 克隆仓库
clone_repository() {
    log_step "克隆Light Node仓库"
    
    if [ -d "light-node" ]; then
        log_warn "light-node目录已存在，跳过克隆"
    else
        git clone https://github.com/Layer-Edge/light-node.git || { log_error "克隆仓库失败"; exit 1; }
        log_info "仓库克隆成功"
    fi
    
    cd light-node
}

# 配置环境变量
configure_environment() {
    log_step "配置环境变量"
    
    # 创建配置文件
    cat > .env << EOL
GRPC_URL=34.31.74.109:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
# 或者使用: ZK_PROVER_URL=https://layeredge.mintair.xyz/
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='cli-node-private-key'
EOL
    
    log_info "环境变量配置文件已创建: .env"
    log_warn "请编辑.env文件，设置您的PRIVATE_KEY和其他必要的环境变量"
    log_info "您可以使用以下命令编辑: nano .env"
}

# 启动Merkle服务
start_merkle_service() {
    log_step "启动Merkle服务"
    
    # 确保环境变量正确设置
    export PATH="$HOME/.risc0/bin:$PATH"
    export RISC0_TOOLCHAIN_PATH="$HOME/.risc0/toolchain"
    
    cd risc0-merkle-service
    log_info "构建Merkle服务..."
    # 显示当前环境变量，帮助调试
    log_info "当前RISC0_TOOLCHAIN_PATH: $RISC0_TOOLCHAIN_PATH"
    log_info "检查risc0工具链是否可用..."
    if ! check_command rzup; then
        log_error "rzup命令未找到，请确保risc0工具链已正确安装"
        exit 1
    fi
    
    cargo build || { log_error "构建Merkle服务失败"; exit 1; }
    
    log_info "启动Merkle服务..."
    log_warn "Merkle服务将在后台运行，日志将输出到merkle-service.log"
    nohup cargo run > merkle-service.log 2>&1 &
    MERKLE_PID=$!
    echo $MERKLE_PID > merkle-service.pid
    
    log_info "等待Merkle服务初始化..."
    sleep 10
    if ps -p $MERKLE_PID > /dev/null; then
        log_info "Merkle服务已成功启动，PID: $MERKLE_PID"
    else
        log_error "Merkle服务启动失败，请检查merkle-service.log"
        exit 1
    fi
    
    cd ..
}

# 构建并运行Light Node
build_and_run_light_node() {
    log_step "构建并运行LayerEdge Light Node"
    
    # 检查并修复go.mod文件中的Go版本格式
    if [ -f "go.mod" ]; then
        log_info "检查go.mod文件..."
        # 查找并修复go版本行，将类似1.23.1的格式改为1.23
        if grep -q "go 1\..*\..*" go.mod; then
            log_info "修复go.mod文件中的Go版本格式..."
            # 使用sed将go 1.xx.x格式改为go 1.xx
            sed -i -E 's/go ([0-9]+)\.([0-9]+)\.[0-9]+/go \1.\2/g' go.mod
            log_info "go.mod文件已修复"
        fi
    fi
    
    log_info "构建Light Node..."
    go build || { log_error "构建Light Node失败"; exit 1; }
    
    log_info "启动Light Node..."
    log_warn "Light Node将在后台运行，日志将输出到light-node.log"
    nohup ./light-node > light-node.log 2>&1 &
    LIGHT_NODE_PID=$!
    echo $LIGHT_NODE_PID > light-node.pid
    
    if ps -p $LIGHT_NODE_PID > /dev/null; then
        log_info "Light Node已成功启动，PID: $LIGHT_NODE_PID"
    else
        log_error "Light Node启动失败，请检查light-node.log"
        exit 1
    fi
}

# 创建管理脚本
create_management_scripts() {
    log_step "创建管理脚本"
    
    # 创建停止脚本
    cat > stop_layeredge.sh << 'EOL'
#!/bin/bash
set -e

if [ -f "light-node.pid" ]; then
    PID=$(cat light-node.pid)
    if ps -p $PID > /dev/null; then
        echo "停止Light Node (PID: $PID)..."
        kill $PID
        echo "Light Node已停止"
    else
        echo "Light Node不在运行状态"
    fi
    rm light-node.pid
fi

if [ -f "risc0-merkle-service/merkle-service.pid" ]; then
    PID=$(cat risc0-merkle-service/merkle-service.pid)
    if ps -p $PID > /dev/null; then
        echo "停止Merkle服务 (PID: $PID)..."
        kill $PID
        echo "Merkle服务已停止"
    else
        echo "Merkle服务不在运行状态"
    fi
    rm risc0-merkle-service/merkle-service.pid
fi
EOL
    chmod +x stop_layeredge.sh
    
    # 创建重启脚本
    cat > restart_layeredge.sh << 'EOL'
#!/bin/bash
set -e

echo "重启LayerEdge服务..."

# 停止服务
./stop_layeredge.sh

# 启动Merkle服务
cd risc0-merkle-service
echo "启动Merkle服务..."
nohup cargo run > merkle-service.log 2>&1 &
MERKLE_PID=$!
echo $MERKLE_PID > merkle-service.pid
echo "Merkle服务已启动，PID: $MERKLE_PID"
cd ..

# 等待Merkle服务初始化
echo "等待Merkle服务初始化..."
sleep 10

# 启动Light Node
echo "启动Light Node..."
nohup ./light-node > light-node.log 2>&1 &
LIGHT_NODE_PID=$!
echo $LIGHT_NODE_PID > light-node.pid
echo "Light Node已启动，PID: $LIGHT_NODE_PID"

echo "LayerEdge服务已重启"
EOL
    chmod +x restart_layeredge.sh
    
    # 创建状态检查脚本
    cat > status_layeredge.sh << 'EOL'
#!/bin/bash

check_service() {
    local pid_file=$1
    local service_name=$2
    
    if [ -f "$pid_file" ]; then
        PID=$(cat $pid_file)
        if ps -p $PID > /dev/null; then
            echo "$service_name 正在运行 (PID: $PID)"
            return 0
        else
            echo "$service_name 不在运行状态，但PID文件存在"
            return 1
        fi
    else
        echo "$service_name 未启动 (PID文件不存在)"
        return 1
    fi
}

echo "LayerEdge服务状态:"
echo "-------------------"

check_service "risc0-merkle-service/merkle-service.pid" "Merkle服务"
check_service "light-node.pid" "Light Node"

echo "\n日志文件:"
echo "-------------------"
echo "Merkle服务日志: risc0-merkle-service/merkle-service.log"
echo "Light Node日志: light-node.log"

echo "\n使用以下命令查看日志:"
echo "tail -f risc0-merkle-service/merkle-service.log"
echo "tail -f light-node.log"
EOL
    chmod +x status_layeredge.sh
    
    log_info "管理脚本已创建:"
    log_info "  - stop_layeredge.sh: 停止所有服务"
    log_info "  - restart_layeredge.sh: 重启所有服务"
    log_info "  - status_layeredge.sh: 检查服务状态"
}

# 显示使用说明
show_instructions() {
    log_step "安装完成"
    
    echo -e "${GREEN}LayerEdge CLI Light Node已成功安装!${NC}"
    echo -e "\n${YELLOW}重要说明:${NC}"
    echo -e "1. 请编辑.env文件设置您的私钥: ${BLUE}nano .env${NC}"
    echo -e "2. 使用以下命令管理服务:"
    echo -e "   - 检查状态: ${BLUE}./status_layeredge.sh${NC}"
    echo -e "   - 停止服务: ${BLUE}./stop_layeredge.sh${NC}"
    echo -e "   - 重启服务: ${BLUE}./restart_layeredge.sh${NC}"
    echo -e "3. 查看日志:"
    echo -e "   - Merkle服务: ${BLUE}tail -f risc0-merkle-service/merkle-service.log${NC}"
    echo -e "   - Light Node: ${BLUE}tail -f light-node.log${NC}"
    echo -e "\n${YELLOW}连接到LayerEdge Dashboard:${NC}"
    echo -e "1. 访问 ${BLUE}dashboard.layeredge.io${NC}"
    echo -e "2. 连接您的钱包"
    echo -e "3. 链接您的CLI节点公钥"
    echo -e "\n${YELLOW}获取CLI节点积分:${NC}"
    echo -e "${BLUE}https://light-node.layeredge.io/api/cli-node/points/{walletAddress}${NC}"
    echo -e "将{walletAddress}替换为您的实际CLI钱包地址"
    echo -e "\n${GREEN}祝您使用愉快!${NC}"
}

# 主函数
main() {
    log_step "开始安装LayerEdge CLI Light Node"
    
    # 检查是否为root用户
    # 自动获取root权限
    if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0" "$@"
        exit $?
    fi
    
    # 执行安装步骤
    install_dependencies
    clone_repository
    configure_environment
    start_merkle_service
    build_and_run_light_node
    create_management_scripts
    show_instructions
}

# 执行主函数
main