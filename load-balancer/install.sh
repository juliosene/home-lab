echo "Installing Keepalived, Nginx and Nginx UI..."
echo "Please, what will be your VIP/CIR? This is the IP address shared between all servers as a single entry point. (ex: 192.168.1.10/24)"
read -p "VIP/CIR: " vip_cir
echo "Now, inform the IPs of your other keepalived servers that will share the same VIP. Do not add this machine IP to the list. Comma separated (ex: 192.168.1.22, 192.168.1.23)"
read -p "servers IPs: " ips_list

myip=$(hostname -I | awk '{print $1}')

password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)

echo "will this machine be the main node (master)?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) state="MASTER";;
        No ) state="SLAVE";;
    esac
done

apt update
apt upgrade -y

# Install keepalived
echo "Installing Keepalived..."
apt install keepalived -y

# Configuring keepalived

ips_servers=""
IFS=','; for word in $ips_list; do ips_servers+=${word}"\n"; done

echo -e $ips_servers| tr -d ' '

curl -fsSL https://raw.githubusercontent.com/juliosene/home-lab/main/load-balancer/keepalived.conf > ~/keepalived.conf

sed -i "s/#PASSWD#/$password/g" ~/keepalived.conf
sed -i "s/#STATE#/$state/g" ~/keepalived.conf
sed -i "s/#MYIP#/$myip/g" ~/keepalived.conf
sed -i "s/#SERVERSIPS#/$ips_servers/g" ~/keepalived.conf
sed -i "s/#VIPCIR#/$vip_cirs/g" ~/keepalived.conf

mv ~/keepalived.conf /etc/keepalived/keepalived.conf

service keepalived restart

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
