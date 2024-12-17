#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SSH_KEY_PATH="~/.ssh/id_rsa"
SSH_USER="ubuntu"

# Get instance metadata
get_instance_metadata() {
    local metadata_token
    metadata_token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    curl -H "X-aws-ec2-metadata-token: $metadata_token" "http://169.254.169.254/latest/meta-data/$1" 2>/dev/null
}

INSTANCE_ID=$(get_instance_metadata "instance-id")
REGION=$(get_instance_metadata "placement/region")

# Usage information
usage() {
    echo "Ubuntu Box 2025 Connection Manager"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  ssh              Connect via SSH"
    echo "  ssm              Connect via AWS Systems Manager Session Manager"
    echo "  tunnel           Create SSH tunnel"
    echo "  port-forward     Create SSM port forwarding"
    echo "  status           Show connection status"
    echo "  copy             Copy files to/from instance"
    echo
    echo "Options:"
    echo "  -p, --port       Port number for tunnel/forwarding"
    echo "  -l, --local      Local port for tunnel/forwarding"
    echo "  -r, --remote     Remote port for tunnel/forwarding"
    echo "  -f, --file       File to copy"
    echo "  -d, --direction  Direction for copy (to/from)"
    echo "  -h, --help       Show this help message"
    echo
    echo "Examples:"
    echo "  $0 ssh                          # Direct SSH connection"
    echo "  $0 ssm                          # SSM session"
    echo "  $0 tunnel -p 8080               # Create SSH tunnel for port 8080"
    echo "  $0 port-forward -l 8080 -r 80   # Forward local port 8080 to remote port 80"
    echo "  $0 copy -f ./file.txt -d to     # Copy file.txt to instance"
    exit 1
}

# Check AWS CLI availability
check_aws_cli() {
    if ! command -v aws >/dev/null 2>&1; then
        echo -e "${RED}Error: AWS CLI not installed${NC}"
        exit 1
    fi
}

# Get instance public IP
get_instance_ip() {
    get_instance_metadata "public-ipv4"
}

# Test SSH connectivity
test_ssh() {
    local ip="$1"
    ssh -q -o BatchMode=yes -o ConnectTimeout=5 -i "$SSH_KEY_PATH" "${SSH_USER}@${ip}" exit 0 2>/dev/null
    return $?
}

# Connect via SSH
connect_ssh() {
    local ip
    ip=$(get_instance_ip)
    echo -e "${BLUE}Connecting to $ip via SSH...${NC}"
    
    if test_ssh "$ip"; then
        ssh -i "$SSH_KEY_PATH" "${SSH_USER}@${ip}"
    else
        echo -e "${RED}Failed to establish SSH connection${NC}"
        exit 1
    fi
}

# Connect via SSM
connect_ssm() {
    check_aws_cli
    echo -e "${BLUE}Connecting via Session Manager...${NC}"
    aws ssm start-session \
        --target "$INSTANCE_ID" \
        --region "$REGION" \
        --document-name AWS-StartInteractiveCommand \
        --parameters command="sudo -i -u ubuntu"
}

# Create SSH tunnel
create_tunnel() {
    local port="$1"
    local ip
    ip=$(get_instance_ip)
    
    echo -e "${BLUE}Creating SSH tunnel for port $port...${NC}"
    echo -e "${YELLOW}Use Ctrl+C to stop the tunnel${NC}"
    
    ssh -i "$SSH_KEY_PATH" -N -L "${port}:localhost:${port}" "${SSH_USER}@${ip}"
}

# Create SSM port forwarding
create_port_forward() {
    local local_port="$1"
    local remote_port="$2"
    
    check_aws_cli
    echo -e "${BLUE}Creating SSM port forward from local port $local_port to remote port $remote_port...${NC}"
    echo -e "${YELLOW}Use Ctrl+C to stop port forwarding${NC}"
    
    aws ssm start-session \
        --target "$INSTANCE_ID" \
        --region "$REGION" \
        --document-name AWS-StartPortForwardingSession \
        --parameters "{\"portNumber\":[\"${remote_port}\"],\"localPortNumber\":[\"${local_port}\"]}"
}

# Show connection status
show_status() {
    local ip
    ip=$(get_instance_ip)
    
    echo -e "${BLUE}Connection Status:${NC}"
    echo -e "Instance ID: ${YELLOW}$INSTANCE_ID${NC}"
    echo -e "Region: ${YELLOW}$REGION${NC}"
    echo -e "Public IP: ${YELLOW}$ip${NC}"
    
    echo -e "\n${BLUE}SSH Status:${NC}"
    if test_ssh "$ip"; then
        echo -e "${GREEN}SSH connection available${NC}"
    else
        echo -e "${RED}SSH connection not available${NC}"
    fi
    
    echo -e "\n${BLUE}SSM Status:${NC}"
    if aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --region "$REGION" >/dev/null 2>&1; then
        echo -e "${GREEN}SSM connection available${NC}"
    else
        echo -e "${RED}SSM connection not available${NC}"
    fi
}

# Copy files to/from instance
copy_files() {
    local file="$1"
    local direction="$2"
    local ip
    ip=$(get_instance_ip)
    
    if [ "$direction" = "to" ]; then
        echo -e "${BLUE}Copying $file to instance...${NC}"
        scp -i "$SSH_KEY_PATH" "$file" "${SSH_USER}@${ip}:~/"
    else
        echo -e "${BLUE}Copying $file from instance...${NC}"
        scp -i "$SSH_KEY_PATH" "${SSH_USER}@${ip}:~/$file" .
    fi
}

# Parse command line arguments
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    ssh)
        connect_ssh
        ;;
    ssm)
        connect_ssm
        ;;
    tunnel)
        if [ $# -lt 2 ] || [ "$1" != "-p" ]; then usage; fi
        create_tunnel "$2"
        ;;
    port-forward)
        if [ $# -lt 4 ] || [ "$1" != "-l" ] || [ "$3" != "-r" ]; then usage; fi
        create_port_forward "$2" "$4"
        ;;
    status)
        show_status
        ;;
    copy)
        if [ $# -lt 4 ] || [ "$1" != "-f" ] || [ "$3" != "-d" ]; then usage; fi
        copy_files "$2" "$4"
        ;;
    *)
        usage
        ;;
esac