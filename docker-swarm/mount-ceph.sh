sudo apt install ceph-common -y

sftp julio@10.0.3.215

mkdir -p /docker/swarmfs

sudo mount -t ceph 10.0.0.33:/ /docker/swarmfs -o name=swarmfs_user,secretfile=/etc/ceph/swarmfs_user.key,fs=swarmfs