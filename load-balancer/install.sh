echo "Installing Keepalived, Nginx and Nginx UI..."

apt update
apt upgrade -y

# Install keepalived
echo "Installing Keepalived..."
apt install keepalived -y

# Install Nginx
echo "Installing Nginx..."
apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring -y
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor     | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
 | sudo tee /etc/apt/sources.list.d/nginx.list
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | sudo tee /etc/apt/preferences.d/99nginx
sudo apt update
sudo apt install nginx -y

# Intall Nginx UI
echo "Installing Nginx UI..."
bash <(curl -L -s https://raw.githubusercontent.com/0xJacky/nginx-ui/master/install.sh) install

# Configuring Nginx and Nginx UI

mkdir /etc//nginx/streams-enabled
mkdir /etc//nginx/streams-available
mkdir /etc/nginx/sites-enabled
mkdir /etc/nginx/sites-available

mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
# wget https://raw.githubusercontent.com/juliosene/home-lab/main/load-balancer/nginx.conf |mv nginx.conf /etc/nginx/nginx.conf

curl -fsSL https://raw.githubusercontent.com/juliosene/home-lab/main/load-balancer/nginx.conf > /etc/nginx/nginx.conf

service nginx restart

echo "Finished!"
echo "to use Nginx UI open in your browser"
echo "http://<your IP>:9000"
