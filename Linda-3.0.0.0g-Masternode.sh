#!/bin/bash
#
# Linda Masternode Linux configuration script
# Giampaolo Murabito - giampaolo.murabito<at>gmail.com
# Releasd under Apache 2 License
# https://www.apache.org/licenses/LICENSE-2.0

# Make verbosity for debugging purposes
# default should be commented
#set -xv

function isEmailValid() {
    regex="^([A-Za-z]+[A-Za-z0-9]*((\.|\-|\_)?[A-Za-z]+[A-Za-z0-9]*){1,})@(([A-Za-z]+[A-Za-z0-9]*)+((\.|\-|\_)?([A-Za-z]+[A-Za-z0-9]*)+){1,})+\.([A-Za-z]{2,})+"
    [[ "${1}" =~ $regex ]]
}

function sendEmail() {
	zip walletbackup.zip passwordFile walletFile walletAddr $dmnRoot/.Linda/wallet.dat && \
	openssl enc -aes-256-cbc -salt -in walletbackup.zip -out walletbackup.zip.enc -k "$encryptBck" && \
	echo "Hello, <br>
		store this email in a secure place !! <br>
		<br>
		<b>Your Passpword</b> for decrypt your backup, through OpenSSL, is <i> "$encryptBck" </i>, 
	  	<br> Check the your wallet address at this <b>Blockchain Explorer</b> and send 2 Milion Linda Coins fo starting the masternode: <a href="https://lindaexplorer.kdhsolutions.co.uk/address/"$walletAddr" "> LINK </a> 
	  	<br> <b>To decrypt</b> your backup file use the following OpenSSL command: <i> openssl enc -aes-256-cbc -d -in walletbackup.zip.enc -out walletbackup.zip -k <password> </i> <br> "\
	   | mail -s "LindaCoin Masternode Configuration" -a 'Content-Type: text/html' $userEmail -A walletbackup.zip.enc 
}

# Run some tests and userdata
## Check Root User
if [ "$EUID" -eq 0 ]
  then echo "EXITING: You should avoid to run the script as root !!"
  exit 1
fi

# Ask user some data
echo "##########################################################"
echo "Linda Coin Masternode v3.0.0.0g Linux configuration script"
echo "Automagically configure your LindaCoin Masternode on Linux"
echo "Sends an OpenSSL encrypted email after the configuration with mail"
echo "##########################################################"

# Define authentication for RPC Username and Password
userRPC=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 10 | tr -d '\n'; echo)
passwordRPC=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 32| tr -d '\n'; echo) 

# Define wallet, wallet password and encryption for backup
wallet=$(strings /dev/urandom | grep -o '[[:digit:]]' | head -n 20 | tr -d '\n'; echo)
walletFile=walletFile
password=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 20 | tr -d '\n'; echo)
passwordFile=passwordFile
encryptBck=$(strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 10 | tr -d '\n'; echo)

# Define Home env vars & dirs
dmnRoot=/home/$USER
dmnConf=$dmnRoot/.Linda/Linda.conf
dmn="$dmnRoot/Lindad"

# Install Lindad Software
wget https://github.com/TheLindaProjectInc/Linda/releases/download/v3.0.0.0/Unix.Lindad-v3.0.0.0g.tar.gz && \
tar zxvf Unix.Lindad-v3.0.0.0g.tar.gz && \
cd ~ && $dmn -daemon && sleep 5

# Bootstrapping Linda
# everything is inside the user dir
wget -O bootstrap_latest.zip https://www.dropbox.com/s/90d3qxu72syb5et/bootstrap_latest.zip?dl=0 && \
unzip bootstrap_latest.zip && \
cp blk0001.dat Linda.conf debug.log peers.dat .Linda && \
cp -R database/*  .Linda/database && \
cp -R txleveldb/* .Linda/txleveldb && \

# Cleaning directory
rm -rf Unix.Lindad-v3.0.0.0g.tar.gz bootstrap_latest.zip Linda.conf \
blk0001.dat bootstrap_latest.zip database debug.log peers.dat txleveldb/ \
db.log wallet.dat Lindad.pid

# Eval Lindad is running...if running stop it
if pgrep -x "Lindad" > /dev/null
	then
		echo "Linda server is running...shutdown it!"
		# Kill Linda Daemon
        	pkill Lindad && sleep 15
	else
		echo "Linda server is not running...go ahead!"
fi 

# Configure Lindad RCP
echo "Configure Linda RCP" && \
sed -i -e "s/rpcuser=.*/rpcuser=$userRPC/; s/rpcpassword=.*/rpcpassword=$passwordRPC/" $dmnConf

# Generate Linda Wallet & Encrypt it
echo "Starting Linda server for address generation and encryption"
$dmn -daemon && sleep 10 && 

# Eval Lindad is running...if running stop it
if pgrep -x "Lindad" > /dev/null
	then
		echo "Linda server is running...GREAT !"
		echo "Continue installation..."
	else
		echo "Linda server is NOT running...Huston we have a problem !"
		exit 1
fi 

# Create conf files
echo $wallet > walletFile && \
echo $password > passwordFile && \

# Configure Wallet & Encrypt
echo "Creating Wallet and Encrypt it..."
$dmn getaccountaddress $(cat walletFile) > walletAddr && sleep 2 && \
$dmn encryptwallet $(cat passwordFile) && sleep 2 && \

# Kill Lindad daemon 
echo "Linda server is running...shutdown it!"
pkill Lindad && sleep 10 && \

# Start Linda daemon with new conf and decrypt wallet 
echo "Starting Lindad Wallet with new conf and decrypt"
$dmn -daemon && sleep 10 && \
$dmn walletpassphrase $(cat passwordFile) 999999999

# Arrange address var for other uses
walletAddr=$(cat walletAddr)
passWalletAddr=$(cat passwordFile)

# Configure Masternode
mnPrivKey=`$dmn dumpprivkey $walletAddr`
publicIP=$(ifconfig eth0 | grep -w inet | awk '{print $2}' | cut -d ":" -f 2)
sed -i "5i staking=0" $dmnConf && \
sed -i "6i masternode=1" $dmnConf && \
sed -i "7i masternodeprivkey=$mnPrivKey" $dmnConf && \
sed -i "8i masternodeaddr=$publicIP:33280" $dmnConf && \

# Kill Linda for Masternode configuration
pkill Lindad && sleep 10 && \

# Finally start masternode
$dmn -daemon && sleep 10 && \
$dmn walletpassphrase $(cat passwordFile) 999999999 && \
$dmn masternode start && \
$dmn masternode debug && sleep 3 && \

# Log on disk date of operation
echo "Logging operation \n"
date > $dmnRoot/masterconf && echo "Configuration done !" >> $dmnRoot/masterconf

# Sending email with zipped/crypted data
##Decrypt a file using a supplied password:
##openssl enc -aes-256-cbc -d -in walletbackup.zip.enc -out walletbackup.zip -k "$encryptBck"

echo "If you have mail utility installed is it possible to send an email, OpenSSL ecnrypted, as backup of you wallet,"
read -p "do you want to send the email ? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

if [ -e "/usr/bin/mail" ]; then 
	read -p "Please insert your email address for backup: " userEmail
else
	echo "mail utility is not installed...exiting !"
	exit 1
fi

if isEmailValid $userEmail; then
        echo "Sending encrypted email with attached backup !"
        sendEmail
else
        echo "EXITING: Invalid Email."
        exit 1
fi

echo "Cleaning Dir..."
rm walletbackup.zip && echo "Masternode ready to receive Linda Coins !!"