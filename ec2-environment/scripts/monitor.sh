#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Ubuntu Box 2025 System Monitor"
    echo
    echo "Usage: $0 [option]"
    echo "Options:"
    echo "  -r, --realtime    Show realtime monitoring (default)"
    echo "  -l, --logs        Show recent system logs"
    echo "  -s, --security    Show security status and recent events"
    echo "  -d, --docker      Show Docker status and resources"
    echo "  -n, --network     Show network statistics"
    echo "  -a, --all         Show all information"
    echo "  -h, --help        Show this help message"
    echo
    echo "Example: $0 --realtime"
    exit 1
}

# Function to print section headers
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to format bytes to human readable
format_bytes() {
    numfmt --to=iec-i --suffix=B "$1"
}

# Function to show real-time system stats
show_realtime() {
    print_header "System Status at $(date)"
    
    # CPU Usage
    echo -e "\n${YELLOW}CPU Usage:${NC}"
    top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print "  Used: " (100 - $1) "%"}'
    
    # Memory Usage
    echo -e "\n${YELLOW}Memory Usage:${NC}"
    free -h | awk 'NR==2{printf "  Used: %s/%s (%.2f%%)\n", $3,$2,$3*100/$2 }'
    
    # Disk Usage
    echo -e "\n${YELLOW}Disk Usage:${NC}"
    df -h / | awk 'NR==2{printf "  Used: %s/%s (%s)\n", $3,$2,$5}'
    
    # Load Average
    echo -e "\n${YELLOW}System Load (1m, 5m, 15m):${NC}"
    uptime | awk -F'load average:' '{print "  " $2}'
    
    # Top Processes
    echo -e "\n${YELLOW}Top 5 CPU-consuming processes:${NC}"
    ps aux --sort=-%cpu | head -6 | awk 'NR>1{printf "  %-20s %5s%%\n", $11, $3}'
    
    echo -e "\n${YELLOW}Top 5 Memory-consuming processes:${NC}"
    ps aux --sort=-%mem | head -6 | awk 'NR>1{printf "  %-20s %5s%%\n", $11, $4}'
}

# Function to show recent system logs
show_logs() {
    print_header "Recent System Logs"
    
    echo -e "\n${YELLOW}Last 10 System Messages:${NC}"
    journalctl -n 10 --no-pager
    
    echo -e "\n${YELLOW}Last 10 Authentication Events:${NC}"
    grep -i "authentication" /var/log/auth.log | tail -10 || true
}

# Function to show security status
show_security() {
    print_header "Security Status"
    
    # fail2ban status
    echo -e "\n${YELLOW}Fail2ban Status:${NC}"
    fail2ban-client status || echo "  fail2ban not running"
    
    # SSH attempts
    echo -e "\n${YELLOW}Recent Failed SSH Attempts:${NC}"
    grep "Failed password" /var/log/auth.log | tail -5 || echo "  No recent failed attempts"
    
    # AIDE status
    echo -e "\n${YELLOW}AIDE Status:${NC}"
    if [ -f /var/lib/aide/aide.db ]; then
        echo "  AIDE database: Present"
        stat /var/lib/aide/aide.db | grep Modify
    else
        echo "  AIDE database: Missing"
    fi
    
    # Listening ports
    echo -e "\n${YELLOW}Open Ports:${NC}"
    ss -tulpn | grep LISTEN
}

# Function to show Docker status
show_docker() {
    print_header "Docker Status"
    
    # Docker service status
    echo -e "\n${YELLOW}Docker Service:${NC}"
    systemctl status docker --no-pager | head -3
    
    # Running containers
    echo -e "\n${YELLOW}Running Containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "  No containers running"
    
    # Docker system info
    echo -e "\n${YELLOW}Docker Resource Usage:${NC}"
    docker system df -v 2>/dev/null || echo "  Unable to get Docker resource usage"
}

# Function to show network statistics
show_network() {
    print_header "Network Statistics"
    
    # Network interfaces
    echo -e "\n${YELLOW}Network Interfaces:${NC}"
    ip -brief addr show
    
    # Connection statistics
    echo -e "\n${YELLOW}Active Connections:${NC}"
    ss -s
    
    # Network usage
    echo -e "\n${YELLOW}Network Usage:${NC}"
    vnstat -h 1 2>/dev/null || echo "  vnstat not installed or no data available"
}

# Process arguments
case "${1:-}" in
    -r|--realtime)
        show_realtime
        ;;
    -l|--logs)
        show_logs
        ;;
    -s|--security)
        show_security
        ;;
    -d|--docker)
        show_docker
        ;;
    -n|--network)
        show_network
        ;;
    -a|--all)
        show_realtime
        echo
        show_logs
        echo
        show_security
        echo
        show_docker
        echo
        show_network
        ;;
    -h|--help)
        usage
        ;;
    *)
        show_realtime
        ;;
esac