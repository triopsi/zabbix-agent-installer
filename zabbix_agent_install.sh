#!/bin/bash
#---------------------------------------------------------------------
# Script: zabbix_agent_install.sh
# Version: 2.1
# Description: Installiere den Zabbix Agenten für Zabbix LTS 5.0.0
# Vorraussetzungen: 
# - Hostname des Host ist richtig gesetzt(Hostname=Zabbix Hostname)
# - Zabbix Server ist am Pollen
# - Der Zabbix Server ist schon installiert und ist einsatzbereit
# ---------------------------------------------------------------------

tput setaf 1
tput clear
RED='\033[0;31m'
GREEN='\e[0;32m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
echo "
  ______         ____  ____ _______   __
 |___  /   /\   |  _ \|  _ \_   _\ \ / /
    / /   /  \  | |_) | |_) || |  \ V / 
   / /   / /\ \ |  _ <|  _ < | |   > <  
  / /__ / ____ \| |_) | |_) || |_ / . \ 
 /_____/_/    \_\____/|____/_____/_/ \_\
                                        
                                        
"

#IP Address Zabbix Master
IP_ZABBIX_SERVER=""
HOSTNAME_ZABBIX_SERVER=""

# ------------------------------------------------------------------------------------------
HOSTNAME_FQDN=$(hostname -f);
IP_ADDRESS=( $(hostname -I) );
RE='^2([0-4][0-9]|5[0-5])|1?[0-9][0-9]{1,2}(\.(2([0-4][0-9]|5[0-5])|1?[0-9]{1,2})){3}$'
IPv4_ADDRESS=( $(for i in ${IP_ADDRESS[*]}; do [[ "$i" =~ $RE ]] && echo "$i"; done) )
APWD=$(pwd);
TOTAL_PHYSICAL_MEM=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
TOTAL_SWAP=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
CPU=( $(sed -n 's/^model name[[:space:]]*: *//p' /proc/cpuinfo | uniq) )
# ------------------------------------------------------------------------------------------
# Checks
#-------------------------------------------------------------------------------------------
# Check if user is root
if [[ $(id -u) -ne 0 ]]; then # $EUID
	echo -e "${RED}Error: This script must be run as root, please run this script again with the root user or sudo.${NC}" >&2
	exit 1
fi

# Check if on Linux
if ! echo "$OSTYPE" | grep -iq "linux"; then
	echo -e "${RED}Error: This script must be run on Linux.${NC}" >&2
	exit 1
fi
# Check connectivity
echo -n "Checking internet connection... "
if ! ping -q -c 3 $HOSTNAME_ZABBIX_SERVER > /dev/null 2>&1; then
	echo -e "${RED}[Error: Could not reach $HOSTNAME_ZABBIX_SERVER, please check your internet connection and run this script again.]${NC}" >&2
	exit 1;
else
    echo -e "${GREEN}[DONE]${NC}\n"
fi

# ------------------------------------------------------------------------------------------
# Logging
#-------------------------------------------------------------------------------------------
#Those lines are for logging purposes
exec > >(tee -i ${APWD}/zabbix_agent_install.log)
exec 2>&1
echo 
echo "Welcome to Zabbix Agent Setup Script V2.1"
echo "========================================="
echo "Zabbix Agent installer"
echo "========================================="

#Paket liste löschen
if [ -f /etc/apt/sources.list.d/zabbix.list ];then
    rm -rf /etc/apt/sources.list.d/zabbix.list
fi

#Checking OS System
#Extract information on system
. /etc/os-release

# Set DISTRO variable to null
DISTRO=''
if echo "$ID" | grep -iq "debian"; then
	#---------------------------------------------------------------------
	#	Debian 9 Stretch
	#---------------------------------------------------------------------	
	if echo "$VERSION_ID" | grep -iq "9"; then
		DISTRO=debian9
        STR_REPO_URL="wget wget https://repo.zabbix.com/zabbix/5.0/debian/pool/main/z/zabbix-release/zabbix-release_5.0-1+stretch_all.deb"
        DISSTR="stretch"
	#---------------------------------------------------------------------
	#	Debian 10 Buster
	#---------------------------------------------------------------------
	elif echo "$VERSION_ID" | grep -iq "10"; then
		DISTRO=debian10
        STR_REPO_URL="wget https://repo.zabbix.com/zabbix/5.0/debian/pool/main/z/zabbix-release/zabbix-release_5.0-1+buster_all.deb"
        DISSTR="buster"
	fi
elif echo "$ID" | grep -iq "ubuntu"; then
    #---------------------------------------------------------------------
	#	Ubuntu 18.04 Bionic Beaver
	#---------------------------------------------------------------------	
	if echo "$VERSION_ID" | grep -iq "18.04"; then
		DISTRO=ubuntu1804
        STR_REPO_URL="wget wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+bionic_all.deb"
        DISSTR="bionic"
    #---------------------------------------------------------------------
	#	Ubuntu 20.04 Focal Fossa
	#---------------------------------------------------------------------	
	elif echo "$VERSION_ID" | grep -iq "20.04"; then
		DISTRO=ubuntu2004
        STR_REPO_URL="wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.0-1+focal_all.deb"
         DISSTR="focal"
    fi

else
    echo -e "${RED}Error: Your OS ist not supported!.${NC}" >&2
    exit 1;
fi

if [ ! -z $DISTRO ];then
    echo -e "Installing for this Linux Distribution:\t ${DISTRO^^}"
	echo -n "Is this correct? (y/n) "
	read -n 1 -r
	echo -e "\n"    # (optional) move to a new line
	RE='^[Yy]$'
	if [[ ! $REPLY =~ $RE ]]; then
		exit 1
	fi
else
    echo -e "${RED}Error: Your OS ist not supported!.${NC}" >&2
    exit 1;
fi
echo -e "The detected Linux Distribution is:\t${PRETTY_NAME:-$ID-$VERSION_ID}"
CPU_CORES=$(nproc --all)
if [ -n "$CPU" ]; then
	echo -e "Processor (CPU):\t\t\t${CPU[*]}"
fi
echo -e "CPU Cores:\t\t\t\t$CPU_CORES"
ARCHITECTURE=$(getconf LONG_BIT)
echo -e "Architecture:\t\t\t\t$HOSTTYPE ($ARCHITECTURE-bit)"
if command -v lspci >/dev/null; then
	GPU=( $(lspci 2>/dev/null | grep -i 'vga\|3d\|2d' | sed -n 's/^.*: //p') )
fi
if [ -n "$GPU" ]; then
	echo -e "Graphics Processor (GPU):\t\t${GPU[*]}"
fi
echo -e "Total memory (RAM):\t\t\t$(printf "%'d" $((TOTAL_PHYSICAL_MEM / 1024))) MiB ($(printf "%'d" $((((TOTAL_PHYSICAL_MEM * 1024) / 1000) / 1000))) MB)"
echo -e "Total swap space:\t\t\t$(printf "%'d" $((TOTAL_SWAP / 1024))) MiB ($(printf "%'d" $((((TOTAL_SWAP * 1024) / 1000) / 1000))) MB)"
echo -e "Computer name:\t\t\t\t$HOSTNAME"
echo -e "Hostname:\t\t\t\t$HOSTNAME_FQDN"
TIME_ZONE=$(timedatectl 2>/dev/null | grep -i 'time zone\|timezone' | sed -n 's/^.*: //p')
echo -e "Time zone:\t\t\t\t$TIME_ZONE"
echo "The IP address is: \t\t\t\t${IP_ADDRESS[0]}"
echo

echo -e "${YELLOW}[I] Zabbix Repository downloaden${RED}"
wget --quiet --no-check-certificate $STR_REPO_URL
if [ $? -ne 0 ];then
    echo -e "${BLUE}[E] --> Das Repository konnte nicht heruntergeladen werden${RED}"
    tput setaf 9
	exit 99
else
    echo -e "${YELLOW}[I] --> Das Repository konnte erfolgreich heruntergeladen werden${RED}"
fi
echo
echo -e "${YELLOW}[I] Weiter mit dem Einlesen des Paketes${RED}"
dpkg -i zabbix-release_5.0-1+${DISSTR}_all.deb
if [ $? -ne 0 ];then
    echo -e "${BLUE}[E] --> Das Repository konnte nicht eingelesen werden${RED}"
    tput setaf 9
	exit 99
else
    echo -e "${YELLOW}[I] --> Das Repository konnte erfolgreich gelesen werden${RED}"
fi
echo
echo -e "${YELLOW}[I] Systemlisten updaten${RED}"
apt-get -qq update
if [ $? -ne 0 ];then
    echo -e "${BLUE}[E] --> Das Repository konnte nicht upgedatet werden${RED}"
    tput setaf 9
	exit 99
else
    echo -e "${YELLOW}[I] --> Das Repository konnte erfolgreich geupdatet werden${RED}"
fi
echo
echo -e "${YELLOW}[I] Zabbix Agenten installieren${RED}"
apt-get install -y zabbix-agent
if [ $? -ne 0 ];then
    echo -e "${BLUE}[E] --> Der Agent konnte nicht installiert werden${RED}"
    tput setaf 9
	exit 99
else
    echo -e "${YELLOW}[I] --> Der Agent wurde erfolgreich installiert${RED}"
fi
echo
echo -e "${YELLOW}[I] Agent stoppen fuer die Anpassungen${RED}"
service zabbix-agent stop
if [ $? -ne 0 ];then
    echo -e "${BLUE}[E] --> Agent konnte nicht gestoppt werden${RED}"
    tput setaf 9
	exit 99
else
	echo
    echo -e "${YELLOW}[I] Ins Verzeichnis wechseln: /etc/zabbix${RED}"
    cd /etc/zabbix/
    echo -e "${YELLOW}[I] Bearbeitungsmodus: Lese Konfigurationsdatei und ersetze diese durch Parameter${RED}"
    if [ -f zabbix_agentd.conf ];then
        sed -i "s/^Server=.*/Server=${IP_ZABBIX_SERVER}/" zabbix_agentd.conf
        sed -i "s/^ServerActive=.*/ServerActive=${IP_ZABBIX_SERVER}/" zabbix_agentd.conf
        sed -i "s/^Hostname=.*/Hostname=${HOSTNAME_FQDN}/" zabbix_agentd.conf
        sed -i 's/^# HostMetadataItem=/HostMetadataItem=system.uname/' zabbix_agentd.conf
        echo
		echo -e "${YELLOW}[I] Starte Agent...${RED}"
        service zabbix-agent start
        if [ $? -eq 0 ];then
            echo -e "${YELLOW}[I] --> Erfoglreich gestartet und konfiguriert.${RED}"
            echo -e "${YELLOW}[I] --> RC=0${RED}"
        else
            echo -e "${BLUE}[E] --> Konnte den Agenten nicht starten${RED}"
            tput setaf 9
			exit 99
        fi
    else
        echo -e "${BLUE}[E] --> Konnte keine Konfigurationsdatei finden${RED}"
        tput setaf 9
		exit 99
    fi
fi
echo
echo -e "\n${GREEN}Well done! Zabbix Agent installed and configured correctly :D${NC} 😃"
tput setaf 9