#!/bin/bash
echo "Installing Docker Swarm..."
echo ""

MANAGER_IP=${1:-0}
TOKEN=${2:-0}
DKR_USER="docker"

IS_SWARM=false
IS_MASTER=false

# Check if Docker is installed
if command -v docker &> /dev/null; then
    read -p "Docker is already installed. Do you want to proceed with the installation and configuration? (yes/no): " PROCEED
    if [ "$PROCEED" != "yes" ]; then
        echo "Installation aborted."
        exit 0
    fi
else
    echo "Docker is not installed. Proceeding with installation."
fi

# Check if Swarm is active
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}')
if [ "$SWARM_STATUS" == "active" ]; then
    echo "Docker Swarm is already active on this machine."
    # Check if the machine is a manager or worker
    NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
    if [ "$NODE_ROLE" == "true" ]; then
        echo "This machine is a manager node in the Docker Swarm."
        IS_MASTER=true
    else
        echo "This machine is a worker node in the Docker Swarm."
        IS_MASTER=false
    fi
    
    # Print messages for adding other workers and managers if the machine is a manager node
    if [ "$IS_MASTER" == "true" ]; then
        MANAGER_IP=$(hostname -I | awk '{print $1}')
        echo ""
        echo "To add swarm worker nodes, use the command:"
        echo ""
        echo "bash install.sh $MANAGER_IP:2377 $(docker swarm join-token -q worker)"
        echo ""
        echo "To add swarm manager nodes, use the command:"
        echo ""
        echo "bash install.sh $MANAGER_IP:2377 $(docker swarm join-token -q manager)"
        echo ""
    fi
    
    exit 0
fi


if [ $MANAGER_IP == 0 ] && [ "$SWARM_STATUS" == "inactive" ]; then
    MANAGER_IP=$(hostname -I | awk '{print $1}')
fi

# Run the following command to uninstall all conflicting packages
sudo apt update
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt upgrade -y


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


# Add Docker's official GPG key
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Test Docker
# sudo docker run hello-world

# Post-installation

# Create the Docker group (if it doesn't exist)
if ! getent group docker; then
    sudo groupadd docker
fi

# Add user to docker
sudo useradd -g docker -m -s /bin/null $DKR_USER

# Add your user to the Docker group (double ckeck)
sudo usermod -aG docker $DKR_USER

echo "" | sudo tee /home/"$DKR_USER"/.docker
sudo chown "$DKR_USER":"$DKR_USER" /home/"$DKR_USER"/.docker -R
sudo chmod g+rwx "/home/"$DKR_USER"/.docker" -R

# Verify that you can run Docker commands without sudo
# docker run hello-world

# Configure Docker to start on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Swarm

# Example iptables rule (order and other tools may require customization)
# iptables -I INPUT -m udp --dport 4789 -m policy --dir in --pol none -j DROP

# Create a new swarm
if [ $TOKEN == 0 ]; then
  # Create a swarm on the manager machine
  sudo -u docker docker swarm init --advertise-addr $MANAGER_IP

  # Check if Swarm is active
  SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}')
  if [ "$SWARM_STATUS" == "active" ]; then
    # Install Portainer
    curl -L https://downloads.portainer.io/ce2-21/portainer-agent-stack.yml -o portainer-agent-stack.yml
    sudo -u docker stack deploy -c portainer-agent-stack.yml portainer
  fi
else
  # Add the machine to swarm cluster as a worker
  sudo -u docker docker swarm join --token $TOKEN $MANAGER_IP
  IP_PORT=$MANAGER_IP
fi

docker info
docker node ls

echo ""
echo "To add swarm worker nodes, use the command:"
echo ""
echo "bash install.sh $MANAGER_IP:2377 $(docker swarm join-token -q worker)"
echo ""
echo "To add swarm manager nodes, use the command:"
echo ""
echo "bash install.sh $MANAGER_IP:2377 $(docker swarm join-token -q manager)"
echo ""
