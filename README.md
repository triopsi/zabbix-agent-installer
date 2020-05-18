# ZABBIX Agent Installer
A bash script for the install and configured a zabbix agent on a linux system.

## Requirement

* The client is a linux system (Debian Stretch, Debian Buster, Ubuntu Bionic, Ubuntu Focal)

### Use

1. Upload the *zabbix_agent_install.sh* in the home directory
2. Edit the script and set up the IP Address and Hostname
```bash
nano zabbix_agent_install.sh 
```
3. Set up the chmod role
```bash
chmod 700 zabbix_agent_install.sh 
```
4. Start the script
```bash
./zabbix_agent_install.sh 
```