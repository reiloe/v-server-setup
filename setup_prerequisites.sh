#! /bin/sh

###################################################################
# Setup script                                                    #
#                                                                 #
# Config of SSH and GIT                                           #
###################################################################

# Check if 2 arguments are given
# If not, the script will stop
if [ "$#" -ne 2 ]
then
  echo "You have to input the Account-Name and IP of the V-Server"
  echo "ex: ./setup_prerequisites.sh bob 1.2.3.4"
  exit 1
fi

USERNAME=$1
VSERVER=$2 
CONN=${USERNAME}@${VSERVER}

###################################################################
# SSH                                                             #
###################################################################

# SSH-KEY creation amd storing in USERHOME/.ssh/da_vserver folder
# Folder is created if not exists
echo "Create SSH-KEY for $USERNAME ..."
mkdir -p ~/.ssh/da_vserver
ssh-keygen -t ed25519 -N "" -f ~/.ssh/da_vserver/da_vserver

# Upload the SSH-KEY to the V-SERVER
echo "Upload SSH-KEY to $VSERVER ..."
ssh-copy-id -i  ~/.ssh/da_vserver/da_vserver.pub -o StrictHostKeyChecking=no "${CONN}"

# Replace placeholder for V-SERVER IP in inventory-File
# Creates a backup of original inventory file
echo "Configure inventory.yml file ..."
sed -i'.bak' "s/#VSERVER-IP/$VSERVER/g" ansible/inventory.yml

# Replace placeholder for V-SERVER IP and USERNAME in ssh_config-File
# Creates a backup of original ssh_configuration file
echo "Configure ssh_configuration file ..."
sed -i'.bak' -e "s/#VSERVER-IP/$VSERVER/g" -e "s/#USERNAME/$USERNAME/g" ssh_configuration

# Include the new configuration file in config of ssh
# Creates a backup of original config file"
echo "# Include the new configuration file in config ..."
sed -i'.bak' '1 i\
Include ~/DeveloperAkademie/Spielwiese/vserver/ssh_ssh_configuration
' ~/.ssh/config

###################################################################
# GIT                                                             #
###################################################################

echo "Configure git file ..."
sed -i'.bak' -e "s/#GIT_USER/$GIT_USER/g" \
-e "s/#GIT_EMAIL/$GIT_USER_EMAIL/g" remote_files/git_config.sh

cd ansible && ansible-playbook -i inventory.yml playbook.yml -K