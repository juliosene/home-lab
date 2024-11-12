#!/bin/bash
# multi Linux distribution Docker Swarm instalation

# URL for the install script
INSTALL_SCRIPT_URL="https://install.cluster4.me"

# Function to print banners
print_banner() {
    echo ""
    echo "=========================================="
    echo "          $1"
    echo "=========================================="
    echo ""
}

print_banner "Starting install.Cluster4.me"

MANAGER_IP=${1:-0}
TOKEN=${2:-0}
DKR_USER="docker"

IS_SWARM=false
IS_MASTER=false

# Detect the OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    print_banner "   ATTENTION!"
    echo "Cannot detect the operating system. Exiting."
    exit 1
fi

# Check if Docker is installed
if command -v docker &> /dev/null; then
    print_banner "    ATTENTION!"
    read -p "Docker is already installed. Do you want to proceed with the installation and configuration? (yes/no): " PROCEED
    if [ "$PROCEED" != "yes" ]; then
        echo "Installation aborted."
        exit 0
    fi
else
    echo "Docker is not installed. Proceeding with installation."
fi

# Function to install Docker on Debian-based systems
install_docker_debian() {
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Function to install Docker on RHEL-based systems
install_docker_rhel() {
    sudo dnf -y remove podman buildah
    sudo dnf -y install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
    sudo systemctl enable docker
}

# Function to configure firewall
configure_firewall() {
    sudo firewall-cmd --permanent --zone=public --add-port=2377/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=7946/tcp
    sudo firewall-cmd --permanent --zone=public --add-port=7946/udp
    sudo firewall-cmd --permanent --zone=public --add-port=4789/udp
    sudo firewall-cmd --permanent --zone=public --add-port=9443/udp
    sudo firewall-cmd --reload
}

# Install Docker based on the detected OS
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    install_docker_debian
elif [[ "$OS" == "rocky" || "$OS" == "centos" ]]; then
    install_docker_rhel
    configure_firewall
else
    print_banner "    ATTENTION!"
    echo "Unsupported operating system: $OS. Attempting to proceed based on package manager detection."

    # Check if the package manager is apt (Debian-based)
    if command -v apt &> /dev/null; then
        echo "Detected apt package manager. Proceeding with Debian-based installation."
        install_docker_debian

    # Check if the package manager is dnf or yum (RHEL-based)
    elif command -v dnf &> /dev/null || command -v yum &> /dev/null; then
        echo "Detected dnf/yum package manager. Proceeding with RHEL-based installation."
        install_docker_rhel
        configure_firewall
    else
        print_banner "   ATTENTION!"
        echo "Unsupported package manager. Exiting."
        exit 1
    fi
fi

# Check if Swarm is active
SWARM_STATUS=$(sudo docker info --format '{{.Swarm.LocalNodeState}}')
if [ "$SWARM_STATUS" == "active" ]; then
    print_banner "   ATTENTION!"
    echo "Docker Swarm is already active on this machine."
    NODE_ROLE=$(sudo docker info --format '{{.Swarm.ControlAvailable}}')
    if [ "$NODE_ROLE" == "true" ]; then
        echo "This machine is a manager node in the Docker Swarm."
        IS_MASTER=true
    else
        echo "This machine is a worker node in the Docker Swarm."
        IS_MASTER=false
    fi
    
    if [ "$IS_MASTER" == "true" ]; then
        MANAGER_IP=$(hostname -I | awk '{print $1}')
        echo ""
        echo "To add swarm manager nodes, use the command:"
        echo ""
        echo "wget $INSTALL_SCRIPT_URL -O install.sh"
        echo "bash install.sh $MANAGER_IP:2377 $(sudo docker swarm join-token -q manager)"
        echo ""
        echo "To add swarm worker nodes, use the command:"
        echo ""
        echo "wget $INSTALL_SCRIPT_URL -O install.sh"
        echo "bash install.sh $MANAGER_IP:2377 $(sudo docker swarm join-token -q worker)"
        echo ""
    fi
    
    exit 0
fi

print_banner "Updating system..."
if [ "$MANAGER_IP" == "0" ]; then
    MANAGER_IP=$(hostname -I | awk '{print $1}')
fi

# Run the following command to uninstall all conflicting packages
sudo timedatectl set-ntp true

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo apt update
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
    sudo apt upgrade -y
elif [[ "$OS" == "rocky" || "$OS" == "centos" ]]; then
    sudo dnf update -y
    for pkg in docker podman buildah; do sudo dnf remove -y $pkg; done
else
    # Attempt to uninstall conflicting packages based on package manager
    if command -v apt &> /dev/null; then
        sudo apt update
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
        sudo apt upgrade -y
    elif command -v dnf &> /dev/null || command -v yum &> /dev/null; then
        sudo dnf update -y
        for pkg in docker podman buildah; do sudo dnf remove -y $pkg; done
    fi
fi

print_banner "Configuring network settings..."
# Function to check and enable sysctl parameters
enable_sysctl_param() {
    local param_name="$1"
    local param_value="$2"

    if [ "$(sysctl -n $param_name)" -ne "$param_value" ]; then
        echo "$param_name = $param_value" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -w "$param_name=$param_value"
        echo "$param_name is now set to $param_value"
    else
        echo "$param_name is already set to $param_value"
    fi
}

# Check and enable bridge-nf-call-iptables
enable_sysctl_param "net.bridge.bridge-nf-call-iptables" 1

# Check and enable bridge-nf-call-ip6tables
enable_sysctl_param "net.bridge.bridge-nf-call-ip6tables" 1

# Apply the changes
sudo sysctl --system

echo "All network changes have been applied."

print_banner "Setting up Docker Swarm..."
# Create a new swarm
if [ $TOKEN == 0 ]; then
    sudo docker swarm init --advertise-addr $MANAGER_IP

    SWARM_STATUS=$(sudo docker info --format '{{.Swarm.LocalNodeState}}')
    if [ "$SWARM_STATUS" == "active" ]; then
        print_banner "Installing Portainer..."
        curl -L https://downloads.portainer.io/ce2-21/portainer-agent-stack.yml -o portainer-agent-stack.yml
        sudo docker stack deploy -c portainer-agent-stack.yml portainer
    fi
else
    sudo docker swarm join --token $TOKEN $MANAGER_IP
fi

print_banner "Final check: Docker Info"
sudo docker info

print_banner "Docker Swarm up and running!"

NODE_ROLE=$(sudo docker info --format '{{.Swarm.ControlAvailable}}')
if [ "$NODE_ROLE" == "true" ]; then
    docker node ls

    echo ""
    echo "To add swarm manager nodes, use the command:"
    echo ""
    echo "wget $INSTALL_SCRIPT_URL -O install.sh"
    echo "bash install.sh $MANAGER_IP:2377 $(sudo docker swarm join-token -q manager)"
    echo ""
    echo "To add swarm worker nodes, use the command:"
    echo ""
    echo "wget $INSTALL_SCRIPT_URL -O install.sh"
    echo "bash install.sh $MANAGER_IP:2377 $(sudo docker swarm join-token -q worker)"
    echo ""
    echo "To have access to Portainer, use the URL:"
    echo "https://$MANAGER_IP:9443"
    echo ""
fi
