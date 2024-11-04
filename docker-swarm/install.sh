echo "Installing Docker Swarm..."

# $VERSION_CODENAME=
USER="docker"
MANAGER_IP="10.0.6.10"



# Run the following command to uninstall all conflicting packages:
apt update
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
apt upgrade -y


# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Testing docker...
sudo docker run hello-world

# post-installation

# Create the docker group.
sudo groupadd docker

# Add your user to the docker group.
sudo usermod -aG docker $USER

sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
sudo chmod g+rwx "$HOME/.docker" -R


# Verify that you can run docker commands without sudo.
docker run hello-world

# Configure Docker to start on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service


# SWARM

# Example iptables rule (order and other tools may require customization)
iptables -I INPUT -m udp --dport 4789 -m policy --dir in --pol none -j DROP

#  create a new swarm
docker swarm init --advertise-addr $MANAGER_IP


# creates a swarm on the manager machine

docker info
docker node ls