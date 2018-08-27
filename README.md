# Linda Coin 
## Unofficial Masternode Configuration Bash Script

![LindaCoin logo](https://avatars3.githubusercontent.com/u/41876146?s=200&v=4)

The following bash script is a VERY SIMPLE bash script by which you can install and configure automagicallty a Linda Coin Masternode.

Check Linda Coin at https://lindacoin.com/

The script should work no every Ubuntu {14|16} release and with very little effort on any distribution.

You need a static public IP tha is included in the Digital Ocean's Droplet with 3vCPU and 1GB RAM that I use.

For having a common base you can use the following procedure after created your instance; you can simply copy/paste and follow the procedure. If you find typos or errors or (better) suggestions you are welcome.

# Time Synchronous
Never underestimate the importance of time synchronous :-)

	# timedatectl set-timezone 'Europe/Rome'

# Create a user for Lindad
Use a good password like or (better) SSH Public/Private Keys
Google it...it is plenty of how-tos

	# useradd linda

# Enable linda user to /etc/sudoers
	# visudo
		# User privilege specification
		root    ALL=(ALL:ALL) ALL
		linda   ALL=(ALL:ALL) ALL

# Avoid root logins
	vi /etc/ssh/sshd_config
		PermitRootLogin no

	service ssh restart
	
# Connect to server with your linda user
Connect and use you sudo bash for continue the procedure

	ssh -l linda <your ip address>

Once logged use your defined password nad become root

	sudo bash
		
# Update & Upgrade the system
Maintain the GRUB version once asked
	
	apt-get update && apt-get -y upgrade

# Add Bitcoin Repository
	add-apt-repository ppa:bitcoin/bitcoin -y
	apt-get update

# Install tools
One of the tools you want to install is mailutils due the "mail" utility that the script will use for send your encrypted wallet backup and other things 

	apt -y install git htop unzip autoconf automake \
	build-essential libtool autotools-dev pkg-config \
	libssl-dev libboost-all-dev mailutils libdb4.8 \
	libdb4.8-dev libdb4.8++-dev libcurl4-openssl-dev \
	python-setuptools

# Install Bitcoin libs
	cd /opt
	git clone https://github.com/bitcoin-core/secp256k1.git
	cd /opt/secp256k1
	./autogen.sh
	./configure && make && make install

# Configure host based firewall
Lindad is listening to 33820 and 33821 tcp ports so we configure the firewall accordingly *without* any other useful ports.

	ufw status
	ufw default deny incoming
	ufw default allow outgoing
	ufw allow ssh/tcp
	ufw limit ssh/tcp
	ufw allow 33820/tcp
	ufw allow 33821/tcp
	ufw logging on
	ufw --force enable
	ufw status

# Add Fail2Ban for suckers
	apt -y install fail2ban
	systemctl enable fail2ban
	systemctl start fail2ban

# Arrange a little bit the TCP/IP Stack
	# vi /etc/sysctl.conf
		# IP Spoofing protection
		net.ipv4.conf.all.rp_filter = 1
		net.ipv4.conf.default.rp_filter = 1

		#Ignore ICMP broadcast requests
		net.ipv4.icmp_echo_ignore_broadcasts = 1

		#Disable source packet routing
		net.ipv4.conf.all.accept_source_route = 0
		net.ipv6.conf.all.accept_source_route = 0 
		net.ipv4.conf.default.accept_source_route = 0
		net.ipv6.conf.default.accept_source_route = 0

		#Ignore send redirects
		net.ipv4.conf.all.send_redirects = 0
		net.ipv4.conf.default.send_redirects = 0

		#Block SYN attacks
		net.ipv4.tcp_syncookies = 1
		net.ipv4.tcp_max_syn_backlog = 2048
		net.ipv4.tcp_synack_retries = 2
		net.ipv4.tcp_syn_retries = 5

		#Log Martians
		net.ipv4.conf.all.log_martians = 1
		net.ipv4.icmp_ignore_bogus_error_responses = 1

		#Ignore ICMP redirects
		net.ipv4.conf.all.accept_redirects = 0
		net.ipv6.conf.all.accept_redirects = 0
		net.ipv4.conf.default.accept_redirects = 0 
		net.ipv6.conf.default.accept_redirects = 0

		#Ignore Directed pings
		net.ipv4.icmp_echo_ignore_all = 1

	# sysctl -p 

# Add swap space
	fallocate -l 2G /swapfile
	chmod 600 /swapfile 
	mkswap /swapfile 
	swapon /swapfile 
	free -h
	
Just configure the system so it will use swap after RAM is used more than 90%

	echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
	echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Dregreasing reboot
We have to be sure that swap configuration is correctly configured, so we reboot !

	shutdown -r now

# Add Rootikit 
Add a rootkit detector that automagically scans for malware and reports daily (crontab preconfiguredin the package) use Gmail+ features for multiple nodes; add your email.

	apt -y install rkhunter
	rkhunter --update 
	rkhunter --propupd
	echo 'MAIL-ON-WARNING=giampa+lindamn@gmail.com' >> /etc/rkhunter.conf 
	echo 'MAIL_CMD=mail -s "[rkhunter] Warnings found for ${HOST_NAME}"' >> /etc/rkhunter.conf && \
	echo 'REPORT_EMAIL="giampa+lindamn@gmail.com"' >> /etc/default/rkhunter

# Cyclic Upgrades
	vi upgradeSystem.sh
		#!/bin/bash
		sudo apt update
		sudo apt -y dist-upgrade
		sudo apt -y autoremove
		sudo rkhunter --propupd
	
	chmod +x upgradeSystem.sh
	./upgradeSystem.sh

# Finally start the script
**IMPORTANT:** Run the script as the *linda* user and not as *root* user !
