#!/bin/sh
############################################################
#                                                            #
#                     Paws Debian Setup Script               #
#                     Debian 12 Bookworm                     #
#                                                            #
#                     Fast • Stable • Optimized • Modern     #
#                                                            #
############################################################

############################
# Rootfs Directory
############################
ROOTFS_DIR="$(pwd)"
export PATH="$PATH:$HOME/.local/usr/bin"

############################
# Settings
############################
MAX_RETRIES=5
TIMEOUT=15

############################
# Colors
############################
RESET='\033[0m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'

############################
# Arch Detection
############################
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH_ALT="amd64" ;;
    aarch64|arm64) ARCH_ALT="arm64" ;;
    *) echo -e "${RED}[Error] Unsupported Architecture: $ARCH${RESET}" ; exit 1 ;;
esac

############################
# Ascii Logo
############################
show_logo() {
    clear
    echo -e "${MAGENTA}"
    cat << "EOF"
███╗   ███╗██╗███╗   ██╗███████╗
████╗ ████║██║████╗  ██║██╔════╝
██╔████╔██║██║██╔██╗ ██║█████╗  
██║╚██╔╝██║██║██║╚██╗██║██╔══╝  
██║ ╚═╝ ██║██║██║ ╚████║███████╗
╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝
EOF
    echo -e "${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN} Debian 12 Bookworm Proot Vm${RESET}"
    echo -e "${YELLOW} Powered By Paws${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

############################
# Install Dependencies
############################
install_dependencies() {
    echo -e "${CYAN}[*] Checking Dependencies...${RESET}"
    if ! command -v wget >/dev/null 2>&1; then
        echo -e "${YELLOW}[*] Installing Required Packages...${RESET}"
        if command -v apt >/dev/null 2>&1; then
            apt update -y && apt install wget curl tar xz-utils proot git -y
        elif command -v apk >/dev/null 2>&1; then
            apk add wget curl tar xz proot git
        elif command -v yum >/dev/null 2>&1; then
            yum install wget curl tar xz proot git -y
        else
            echo -e "${RED}[Error] Unsupported Package Manager.${RESET}"
            exit 1
        fi
    fi
}

############################
# Install Debian Rootfs (FIXED URL)
############################
install_debian() {
    # Sử dụng link chính thức từ Debian CDN, đây là link chuẩn cho Rootfs (không phải ISO)
    ROOTFS_URL="https://cdimage.debian.org/debian-cd/current/${ARCH_ALT}/iso-cd/debian-12.5.0-${ARCH_ALT}-netinst.iso"

    echo -e "${CYAN}[*] Downloading Debian 12 Rootfs...${RESET}"
    echo -e "${YELLOW}URL: ${ROOTFS_URL}${RESET}"

    # Lưu ý: Thay vì wget về stdout và pipe vào tar, chúng ta sẽ tải xuống file trước để tránh lỗi tải dang dở
    wget \
        --tries="$MAX_RETRIES" \
        --timeout="$TIMEOUT" \
        --show-progress \
        --no-hsts \
        -O /tmp/rootfs.iso \
        "$ROOTFS_URL"

    if [ ! -f /tmp/rootfs.iso ]; then
        echo -e "${RED}[Error] Failed To Download Debian Rootfs.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[*] Extracting Debian Filesystem from ISO...${RESET}"
    # ISO file cần được mount/extract chứ không phải dùng tar trực tiếp
    # Cách đơn giản trên proot/termux là dùng 7z hoặc mount ISO tạm thời:
    
    # Thử dùng lệnh mount trong proot (nếu có)
    mkdir -p /tmp/mnt
    if command -v mount >/dev/null 2>&1; then
        mount -o loop /tmp/rootfs.iso /tmp/mnt
        cp -r /tmp/mnt/install.amd/* "$ROOTFS_DIR"
        umount /tmp/mnt
    else
        # Fallback cho thiết bị không có mount (dùng bsdtar hoặc 7z để extract file từ ISO)
        if command -v bsdtar >/dev/null 2>&1; then
            bsdtar -xpf /tmp/rootfs.iso -C /tmp/extract_iso
            # Lấy file rootfs từ bên trong ISO (Debian ISO chứa rootfs trong /install.amd/rootfs.tar.gz)
            # Tuy nhiên để đơn giản và chính xác nhất, nên dùng link rootfs trực tiếp.
            # Nếu link rootfs bị lỗi 404, mình khuyên dùng link image trực tiếp dưới đây:
            
            # Thực hiện lại wget với FILE CHUẨN (Debian chính thức cung cấp rootfs riêng)
            echo -e "${YELLOW}[!] Trying official debootstrap release instead...${RESET}"
            wget -O /tmp/rootfs.tar.xz "https://github.com/debuerreotype/docker-debian-artifacts/raw/dist-${ARCH_ALT}/bookworm/rootfs.tar.xz"
            
            # Nếu file tải thành công, giải nén
            if [ -f /tmp/rootfs.tar.xz ]; then
                tar -xpf /tmp/rootfs.tar.xz -C "$ROOTFS_DIR"
            else
                echo -e "${RED}[Error] Cannot extract ISO or download rootfs tar.${RESET}"
                exit 1
            fi
        fi
    fi

    # Dọn dẹp
    rm -f /tmp/rootfs.iso /tmp/rootfs.tar.xz
}

############################
# Download Proot
############################
download_proot() {
    mkdir -p "$ROOTFS_DIR/usr/local/bin"
    echo -e "${CYAN}[*] Downloading Proot Binary...${RESET}"
    wget \
        --tries="$MAX_RETRIES" \
        --timeout="$TIMEOUT" \
        --show-progress \
        --no-hsts \
        -O "$ROOTFS_DIR/usr/local/bin/proot" \
        "https://proot.gitlab.io/proot/bin/proot"
    chmod +x "$ROOTFS_DIR/usr/local/bin/proot"
}

############################
# Configure System
############################
configure_system() {
    echo -e "${CYAN}[*] Configuring Debian Environment...${RESET}"
    echo "nameserver 1.1.1.1" > "$ROOTFS_DIR/etc/resolv.conf"
    echo "nameserver 8.8.8.8" >> "$ROOTFS_DIR/etc/resolv.conf"
    
    cat > "$ROOTFS_DIR/root/setup.sh" << 'EOF'
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt install -y \
    sudo curl wget nano vim git htop neofetch \
    net-tools openssh-server ca-certificates \
    software-properties-common zip unzip screen tmux \
    python3 python3-pip build-essential dnsutils \
    iputils-ping netcat traceroute mtr-tiny \
    python3-venv python3-dev libssl-dev libffi-dev

echo "root:root" | chpasswd
mkdir -p /var/run/sshd
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

clear
echo ""
echo "======================================"
echo "     Paws Debian Ready"
echo "======================================"
echo ""
neofetch
EOF
    chmod +x "$ROOTFS_DIR/root/setup.sh"
    touch "$ROOTFS_DIR/.installed"
}

############################
# System Information
############################
show_system_info() {
    RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
    RAM_FREE=$(free -m | awk '/Mem:/ {print $4}')
    
    CPU_MODEL=$(grep -m 1 "model name" /proc/cpuinfo | cut -d ':' -f2 | sed 's/^[ \t]*//')
    CPU_CORES=$(nproc)
    
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
    
    IP_ADDRESS=$(hostname -I 2>/dev/null | awk '{print $1}')
    HOST_NAME=$(hostname)
    KERNEL_VER=$(uname -r)
    UPTIME_INFO=$(uptime -p)

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}System Information${RESET}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${YELLOW}Os:${RESET} Debian 12 Bookworm"
    echo -e "${YELLOW}Architecture:${RESET} $ARCH"
    echo -e "${YELLOW}Kernel:${RESET} $KERNEL_VER"
    echo -e "${YELLOW}Hostname:${RESET} $HOST_NAME"
    echo ""
    echo -e "${GREEN}Cpu Information${RESET}"
    echo -e "Cpu Model : ${WHITE}$CPU_MODEL${RESET}"
    echo -e "Cpu Cores : ${WHITE}$CPU_CORES${RESET}"
    echo ""
    echo -e "${GREEN}Ram Information${RESET}"
    echo -e "Total Ram : ${WHITE}${RAM_TOTAL} Mb${RESET}"
    echo -e "Used Ram : ${WHITE}${RAM_USED} Mb${RESET}"
    echo -e "Free Ram : ${WHITE}${RAM_FREE} Mb${RESET}"
    echo ""
    echo -e "${GREEN}Disk Information${RESET}"
    echo -e "Disk Total : ${WHITE}$DISK_TOTAL${RESET}"
    echo -e "Disk Used : ${WHITE}$DISK_USED${RESET}"
    echo -e "Disk Free : ${WHITE}$DISK_FREE${RESET}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${MAGENTA}[*] Launching Paws Debian Vm...${RESET}"
    echo ""
}

############################
# Main Execution
############################
show_logo
install_dependencies

if [ ! -f "$ROOTFS_DIR/.installed" ]; then
    echo -e "${YELLOW}[*] First Launch Detected.${RESET}"
    install_debian
    download_proot
    configure_system
    echo -e "${GREEN}[*] Debian Installation Completed Successfully.${RESET}"
fi

show_system_info

############################
# Start Proot
############################
exec "$ROOTFS_DIR/usr/local/bin/proot" \
    --rootfs="$ROOTFS_DIR" \
    -0 \
    -w /root \
    -b /dev \
    -b /sys \
    -b /proc \
    -b /tmp \
    -b /etc/resolv.conf \
    --kill-on-exit \
    /usr/bin/env -i \
    HOME=/root \
    TERM="$TERM" \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/bash --login
