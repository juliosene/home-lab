echo "Installing Docker Swarm..."
echo ""


MANAGER_IP=${1:-0}
#MANAGER_IP=0
TOKEN=${2:-0}
#USER=${3:'docker'}
DKR_USER="docker"


if [ $MANAGER_IP == 0 ]
then
    MANAGER_IP=$(hostname -I | awk '{print $1}')
#    echo "Please, what will be your manager IP? This is the IP address used by Swarm master node. (ex: 192.168.1.10)"
#    read -p "Manager IP: " MANAGER_IP
fi


# Run the following command to uninstall all conflicting packages:
apt update
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
apt upgrade -y


# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install  -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Testing docker...
sudo docker run hello-world

# post-installation

# Add user to docker
sudo adduser --disabled-password --gecos "" $DKR_USER

# Create the docker group.
sudo groupadd docker

# Add your user to the docker group.
sudo usermod -aG docker $DKR_USER

echo "" > /home/"$DKR_USER"/.docker
sudo chown "$DKR_USER":"$DKR_USER" /home/"$DKR_USER"/.docker -R
sudo chmod g+rwx "/home/"$DKR_USER"/.docker" -R


# Verify that you can run docker commands without sudo.
docker run hello-world

# Configure Docker to start on boot with systemd
sudo systemctl enable docker.service
sudo systemctl enable containerd.service


# SWARM

# Example iptables rule (order and other tools may require customization)
iptables -I INPUT -m udp --dport 4789 -m policy --dir in --pol none -j DROP

#  create a new swarm

if [ $TOKEN == 0 ]
then
  # creates a swarm on the manager machine
  OUTPUT=$(docker swarm init --advertise-addr $MANAGER_IP)
  # find the token and IP:port for other nodes
  for word in $OUTPUT; do if [[ $next == 2 ]]; then TOKEN=$word;((next--)); else if [[ $next == 1 ]]; then IP_PORT=$word;((next--)); fi; fi;  if [ $word == "--token" ]; then next=2; fi; done
else
  # add the machine to swarm cluster as a worker
  sudo  docker swarm join --token $TOKEN $MANAGER_IP
fi

docker info
docker node ls

echo ""
echo "To install swarm worker nodes, use the command:"
echo ""
echo "bash install.sh $IP_PORT $TOKEN"
echo ""