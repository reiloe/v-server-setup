#! /bin/bash

###################################################################
# Setup script                                                    #
#                                                                 #
# Config of SSH and GIT                                           #
###################################################################

# Check if 3 arguments are given
# If not, the script will stop
if [ "$#" -ne 3 ]
then
  echo "Something went wrong!!!"
  echo "You have to input 3 Paramaters:"
  echo "Account-Name, IP and environment"
  echo "ex: ./setup_prerequisites.sh bob 1.2.3.4 dev"
  exit 1
fi

USERNAME=$1
VSERVER=$2
ENVIRONMENT=$3
CONN=${USERNAME}@${VSERVER}
SSH_KEY_FOLDER=~/.ssh/da_vserver
FILE=$SSH_KEY_FOLDER/da_vserver_"$ENVIRONMENT"

if ! test -d "$SSH_KEY_FOLDER"; then
  echo "Create folder to store the keys..."
  mkdir -p SSH_KEY_FOLDER
fi
###################################################################
# SSH                                                             #
###################################################################

# SSH-KEY creation and upload

confirm() {
    while true; do
        read -p "$1 (y/n): " -n 1 -r
        echo    # new line
        case $REPLY in
            [Yy] ) return 0;;
            [Nn] ) return 1;;
            * ) echo "Invalid response.";;
        esac
    done
}

create_ssh_key(){
    ssh-keygen -t ed25519 -N "" -f $SSH_KEY_FOLDER/da_vserver_"$1"
}

upload_ssh_key(){
  echo "Upload SSH-KEY to $VSERVER ..."
  ssh-copy-id -i  $SSH_KEY_FOLDER/da_vserver_"$ENVIRONMENT".pub -o StrictHostKeyChecking=no "${CONN}"
}

if test -f "$FILE"; then
    echo "SSH key pair already exists. The keys are being overwritten."
    if confirm "Do you want to continue?"; then
        echo "Overwrite keys..."
        /bin/rm -f "$FILE"
        /bin/rm -f "$FILE.pub"
        create_ssh_key "$ENVIRONMENT"
        upload_ssh_key  
    else
    echo "Cancelled."
    fi
else
    echo "Create SSH-KEY for environment: $ENVIRONMENT..."
    create_ssh_key "$ENVIRONMENT"
    upload_ssh_key
fi

# Replace placeholder for V-SERVER IP in inventory-File
# Creates a backup of original inventory file
echo "Configure inventory.yml file ..."
sed -i'.bak' "s/#VSERVER-IP/$VSERVER/g" ansible/inventory.yml

# Replace placeholder for V-SERVER IP and USERNAME in ssh_config-File
# Creates a backup of original ssh_configuration file
echo "Configure ssh_configuration file ..."
sed -i'.bak' -e "s/#VSERVER-IP/$VSERVER/g" -e "s/#USERNAME/$USERNAME/g" -e "s/#KEYPATH/$SSH_KEY_FOLDER/da_vserver_$ENVIRONMENT/g" ssh_configuration

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