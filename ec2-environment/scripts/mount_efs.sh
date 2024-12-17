#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_MOUNT_DIR="/mnt/efs"
FSTAB_FILE="/etc/fstab"
EFS_UTILS_CONF="/etc/amazon/efs/efs-utils.conf"

# Usage information
usage() {
    echo "Ubuntu Box 2025 EFS Mount Manager"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  mount         Mount an EFS filesystem"
    echo "  unmount       Unmount an EFS filesystem"
    echo "  status        Show mount status"
    echo "  list          List available EFS filesystems"
    echo "  verify        Verify mount point and performance"
    echo
    echo "Options:"
    echo "  -f, --fs-id     EFS filesystem ID (required for mount/unmount)"
    echo "  -p, --path      Mount path (default: /mnt/efs/<fs-id>)"
    echo "  -o, --opts      Additional mount options"
    echo "  -t, --type      Performance test type (basic|full) for verify command"
    echo "  -h, --help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 mount -f fs-1234567"
    echo "  $0 mount -f fs-1234567 -p /custom/mount/path"
    echo "  $0 unmount -f fs-1234567"
    echo "  $0 status -f fs-1234567"
    echo "  $0 verify -f fs-1234567 -t full"
    exit 1
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    if ! command -v mount.efs >/dev/null 2>&1; then
        echo -e "${RED}Error: amazon-efs-utils not installed${NC}"
        exit 1
    fi
}

# Get AWS region
get_region() {
    aws configure get region 2>/dev/null || curl -s http://169.254.169.254/latest/meta-data/placement/region
}

# Get default mount point for filesystem
get_mount_point() {
    local fs_id="$1"
    local custom_path="${2:-}"
    
    if [ -n "$custom_path" ]; then
        echo "$custom_path"
    else
        echo "${DEFAULT_MOUNT_DIR}/${fs_id}"
    fi
}

# Verify EFS filesystem ID
verify_fs_id() {
    local fs_id="$1"
    local region
    region=$(get_region)
    
    if ! aws efs describe-file-systems --file-system-id "$fs_id" --region "$region" >/dev/null 2>&1; then
        echo -e "${RED}Error: EFS filesystem $fs_id not found${NC}"
        exit 1
    fi
}

# Mount EFS filesystem
mount_efs() {
    local fs_id="$1"
    local mount_point
    mount_point=$(get_mount_point "$fs_id" "${2:-}")
    local mount_opts="${3:-tls,iam}"
    
    echo -e "${BLUE}Mounting EFS filesystem $fs_id to $mount_point...${NC}"
    
    # Create mount point if it doesn't exist
    mkdir -p "$mount_point"
    
    # Check if already mounted
    if mountpoint -q "$mount_point"; then
        echo -e "${YELLOW}Filesystem already mounted at $mount_point${NC}"
        return 0
    fi
    
    # Mount EFS
    if mount -t efs -o "$mount_opts" "$fs_id:/" "$mount_point"; then
        echo -e "${GREEN}Successfully mounted EFS filesystem${NC}"
        
        # Add to fstab if not already present
        if ! grep -qs "$fs_id" "$FSTAB_FILE"; then
            echo "$fs_id:/ $mount_point efs _netdev,$mount_opts 0 0" >> "$FSTAB_FILE"
            echo -e "${GREEN}Added mount entry to $FSTAB_FILE${NC}"
        fi
    else
        echo -e "${RED}Failed to mount EFS filesystem${NC}"
        exit 1
    fi
}

# Unmount EFS filesystem
unmount_efs() {
    local fs_id="$1"
    local mount_point
    mount_point=$(get_mount_point "$fs_id" "${2:-}")
    
    echo -e "${BLUE}Unmounting EFS filesystem $fs_id from $mount_point...${NC}"
    
    # Check if mounted
    if ! mountpoint -q "$mount_point"; then
        echo -e "${YELLOW}Filesystem not mounted at $mount_point${NC}"
        return 0
    fi
    
    # Unmount EFS
    if umount "$mount_point"; then
        echo -e "${GREEN}Successfully unmounted EFS filesystem${NC}"
        
        # Remove from fstab
        sed -i "\|$fs_id:|d" "$FSTAB_FILE"
        echo -e "${GREEN}Removed mount entry from $FSTAB_FILE${NC}"
        
        # Remove empty mount point
        rmdir "$mount_point" 2>/dev/null || true
    else
        echo -e "${RED}Failed to unmount EFS filesystem${NC}"
        exit 1
    fi
}

# Show mount status
show_status() {
    local fs_id="$1"
    local mount_point
    mount_point=$(get_mount_point "$fs_id" "${2:-}")
    
    echo -e "${BLUE}EFS Mount Status:${NC}"
    echo -e "Filesystem ID: ${YELLOW}$fs_id${NC}"
    echo -e "Mount Point: ${YELLOW}$mount_point${NC}"
    
    if mountpoint -q "$mount_point"; then
        echo -e "Status: ${GREEN}Mounted${NC}"
        echo -e "\nMount Details:"
        df -h "$mount_point"
        
        echo -e "\nActive Connections:"
        lsof "$mount_point" 2>/dev/null || echo "No active connections"
    else
        echo -e "Status: ${RED}Not Mounted${NC}"
    fi
    
    if grep -qs "$fs_id" "$FSTAB_FILE"; then
        echo -e "\nFSTAB Entry: ${GREEN}Present${NC}"
        grep "$fs_id" "$FSTAB_FILE"
    else
        echo -e "\nFSTAB Entry: ${RED}Not Present${NC}"
    fi
}

# List available EFS filesystems
list_filesystems() {
    local region
    region=$(get_region)
    
    echo -e "${BLUE}Available EFS Filesystems:${NC}"
    aws efs describe-file-systems --region "$region" --query 'FileSystems[*].[FileSystemId,Name,Size]' --output table
}

# Verify mount point performance
verify_mount() {
    local fs_id="$1"
    local mount_point
    mount_point=$(get_mount_point "$fs_id" "${2:-}")
    local test_type="${3:-basic}"
    
    echo -e "${BLUE}Verifying EFS mount point performance...${NC}"
    
    # Check if mounted
    if ! mountpoint -q "$mount_point"; then
        echo -e "${RED}Error: Filesystem not mounted${NC}"
        exit 1
    fi
    
    # Create test directory
    local test_dir="$mount_point/test_$(date +%s)"
    mkdir -p "$test_dir"
    
    echo -e "\n${YELLOW}Running basic write test...${NC}"
    dd if=/dev/zero of="$test_dir/test_file" bs=1M count=100 conv=fsync 2>&1
    
    echo -e "\n${YELLOW}Running basic read test...${NC}"
    dd if="$test_dir/test_file" of=/dev/null bs=1M 2>&1
    
    if [ "$test_type" = "full" ]; then
        echo -e "\n${YELLOW}Running metadata test...${NC}"
        time for i in {1..1000}; do touch "$test_dir/file_$i"; done
        
        echo -e "\n${YELLOW}Running concurrent access test...${NC}"
        parallel -j 4 dd if=/dev/zero of="$test_dir/parallel_{}" bs=1M count=10 ::: {1..4}
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    echo -e "\n${GREEN}Verification complete${NC}"
}

# Main logic
check_prerequisites

# Parse command line arguments
COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    mount)
        check_root
        while [ $# -gt 0 ]; do
            case "$1" in
                -f|--fs-id) FS_ID="$2"; shift ;;
                -p|--path) MOUNT_PATH="$2"; shift ;;
                -o|--opts) MOUNT_OPTS="$2"; shift ;;
                *) usage ;;
            esac
            shift
        done
        verify_fs_id "${FS_ID:-}"
        mount_efs "${FS_ID:-}" "${MOUNT_PATH:-}" "${MOUNT_OPTS:-}"
        ;;
    unmount)
        check_root
        while [ $# -gt 0 ]; do
            case "$1" in
                -f|--fs-id) FS_ID="$2"; shift ;;
                -p|--path) MOUNT_PATH="$2"; shift ;;
                *) usage ;;
            esac
            shift
        done
        unmount_efs "${FS_ID:-}" "${MOUNT_PATH:-}"
        ;;
    status)
        while [ $# -gt 0 ]; do
            case "$1" in
                -f|--fs-id) FS_ID="$2"; shift ;;
                -p|--path) MOUNT_PATH="$2"; shift ;;
                *) usage ;;
            esac
            shift
        done
        show_status "${FS_ID:-}" "${MOUNT_PATH:-}"
        ;;
    list)
        list_filesystems
        ;;
    verify)
        while [ $# -gt 0 ]; do
            case "$1" in
                -f|--fs-id) FS_ID="$2"; shift ;;
                -p|--path) MOUNT_PATH="$2"; shift ;;
                -t|--type) TEST_TYPE="$2"; shift ;;
                *) usage ;;
            esac
            shift
        done
        verify_mount "${FS_ID:-}" "${MOUNT_PATH:-}" "${TEST_TYPE:-basic}"
        ;;
    *)
        usage
        ;;
esac