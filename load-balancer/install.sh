syncuser="rsync"


echo "Installing Keepalived, Nginx and Nginx UI..."

vip=${1:-0}
cir=${2:-0}
ips_list=${3:-0}

if [ $ips_list == 0 ]
then
    echo "Please, what will be your VIP? This is the IP address shared between all servers as a single entry point. (ex: 192.168.1.10)"
    read -p "VIP: " vip
    echo "What will be your network CIR (netmask)?  (ex: when your network is somthing like 192.168.1.10/24 your CIR is 24)"
    read -p "CIR: " cir
    echo "Now, inform the IPs of your other keepalived servers that will share the same VIP. Do not add this machine IP to the list. Comma separated (ex: 192.168.1.22, 192.168.1.23)"
    read -p "servers IPs: " ips_list
fi


myip=$(hostname -I | awk '{print $1}')

interface=$(ip address| grep BROADCAST| awk '{print $2}' | awk 'NR==1' | cut -d: -f1 | cut -d@ -f1)

password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8; echo)
password=${4:-$password}

syncpasswd=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 24; echo)
syncpasswd=${5:-$syncpasswd}

yn=${6:-0}

if [ $yn == 0 ]
then
  echo "will this machine be the main node (master)?"
  select yn in "Yes" "No"; do
      case $yn in
          Yes ) echo "this server will be the MASTER";break;;
          No ) echo "this server will be a BACKUP";break;;
      esac
  done
fi  


if [ $yn == "No" ]
then
    echo "Please, type the keepalived password generated on the master node."
    read -p "Master node password: " password
    priority=$(expr 100 + $(\tr -dc 0-9 </dev/urandom | head -c 2; echo))
    state="BACKUP"
else
    priority=200
    state="BACKUP"
fi

apt update
apt upgrade -y

# Install keepalived
echo "Installing Keepalived..."
apt install keepalived -y

# Configuring keepalived

ips_servers=""
syncservers=""
IFS=','; for word in $ips_list; do ips_servers+=${word}"\n"; syncservers+=${word}" "; done

echo -e $ips_servers| tr -d ' '

curl -fsSL https://raw.githubusercontent.com/juliosene/home-lab/main/load-balancer/keepalived.conf > ~/keepalived.conf

sed -i "s/#PASSWD#/$password/g" ~/keepalived.conf
sed -i "s/#STATE#/$state/g" ~/keepalived.conf
sed -i "s/#MYIP#/$myip/g" ~/keepalived.conf
sed -i "s/#SERVERSIPS#/$ips_servers/g" ~/keepalived.conf
sed -i "s/#VIP#/$vip/g" ~/keepalived.conf
sed -i "s/#CIR#/$cir/g" ~/keepalived.conf
sed -i "s/#PRIORITY#/$priority/g" ~/keepalived.conf
sed -i "s/#INTERFACE#/$interface/g" ~/keepalived.conf
 
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

mkdir /etc/nginx/streams-enabled
mkdir /etc/nginx/streams-available
mkdir /etc/nginx/sites-enabled
mkdir /etc/nginx/sites-available

mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
# wget https://raw.githubusercontent.com/juliosene/home-lab/main/load-balancer/nginx.conf |mv nginx.conf /etc/nginx/nginx.conf

curl -fsSL https://raw.githubusercontent.com/juliosene/home-lab/main/load-balancer/nginx.conf > /etc/nginx/nginx.conf

mkdir /var/local/websites

service nginx restart

# Install syncronization
apt install rsync sshpass -y

useradd -p $(openssl passwd -1 $syncpasswd) $syncuser

echo "$syncuser ALL= NOPASSWD:/usr/bin/rsync" >> /etc/sudoers


curl -fsSL https://raw.githubusercontent.com/juliosene/home-lab/main/load-balancer/sync-nginx.sh > /usr/bin/sync-nginx.sh
chmod 711 /usr/bin/sync-nginx.sh

sed -i "s/#PASSWD#/$syncpasswd/g" /usr/bin/sync-nginx.sh
sed -i "s/#STATE#/$syncuser/g" /usr/bin/sync-nginx.sh
sed -i "s/#MYIP#/$$syncservers/g" /usr/bin/sync-nginx.sh

# add rsync to cron (5every min sync)
echo "* * * * * root /usr/bin/sync-nginx.sh &> /dev/null" > /etc/cron.d/nginx-rsync
service cron restart


echo "Finished!"
echo ""
echo "to use Nginx UI open in your browser"
echo "http://$myip:9000"
echo ""

if [ $yn == "Yes" ]; then
    echo "Take note of the following password. It will be required for the configuration of the BACKUP node."
    echo ""
    echo "$password"
    echo ""
    echo ""
    echo ""
    IFS=',' read -a ip_array <<< "$ips_list"

    for ip in ${ip_array[@]}
    do
        echo ""
        echo ""
        echo ""        
        echo "bash install.sh $vip $cir $(sed "s/$ip/$myip/g" <<< "$ips_list") $password $syncpasswd $yn"
        echo ""
    done

fi