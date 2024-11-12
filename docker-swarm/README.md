
# Cluster4.me Setup Script

This script is designed to set up a Docker Swarm cluster with Portainer on Ubuntu Server 24.04 LTS. Follow the instructions below to prepare your environment and execute the script.

## Prerequisites

1. **Operating System**:
   - The script has been tested on:
      ubuntu 24.04
      debian 12.8
      rocky 9.4
      alma 9.4
    you can choose to use one of them or a mix of them. Until now, no problems have been detected in creating an environment with multiple Linux distributions as a base for this scrip.

2. **Machines for the Cluster**:
   - Provide the machines that will be used in the cluster.
   - We recommend at least one machine as a manager and two as workers.

3. **Disk Space**:
   - Recommended minimum disk space is 20 GB.
   - We recommend 50 GB or more to avoid issues with applications that will be installed later.
   - The required space will depend on the planned use for the environment.

4. **Internet Access**:
   - Ensure all machines used in the cluster have internet access during the installation process.

5. **IP Configuration and Firewall**:
   - Configure the machines with fixed IPs (at least the manager).
   - Open the necessary ports for communication between the machines in case of firewall blockage.


## Preparation Instructions

1. **Open terminals** for the servers where you intend to install the script. The session can be under a regular user, but root access might be required for some actions.

2. In the terminal for the manager server, **copy and paste the instruction below**.
```
wget https://install.cluster4.me -O install.sh
bash install.sh
```

3. At the end, the script will provide instructions to run the same script with the correct parameters to create new worker or manager nodes, as well as the instructions to access Portainer, the management tool we installed.

4. **Access Portainer** and set up your user and password. **ATTENTION**: For security reasons, Portainer limits the maximum time for you to register. We advise you to do this immediately after the installation of the manager node.
```
https://<MANAGER_IP>:9443"
```

5. **Use the commands** provided at the end of the manager creation process to create other workers and managers.

## Useful Commands for Validation

- `docker node ls`: Lists nodes in the cluster.
- `docker service ls`: Lists running services.
- `docker network ls`: Lists virtual networks created for the execution of environments.
