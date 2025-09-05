#! /bin/sh

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
            * ) echo "Invalid key pressed.";;
        esac
    done
}

create_and_upload_ssh_key(){
    echo "Create SSH-KEY for environment: $ENVIRONMENT..."
    ssh-keygen -t ed25519 -N "" -f $SSH_KEY_FOLDER/da_vserver_"$ENVIRONMENT"

    echo "Upload SSH-KEY to $VSERVER ..."
    ssh-copy-id -i  $SSH_KEY_FOLDER/da_vserver_"$ENVIRONMENT".pub -o StrictHostKeyChecking=no "${CONN}"
}

if test -f "$FILE"; then
    echo "SSH key pair already exists. The keys are being overwritten."
    if confirm "Do you want to continue?"; then
        echo "Overwrite keys..."
        /bin/rm -f "$FILE"
        /bin/rm -f "$FILE.pub"
        create_and_upload_ssh_key  
    else
        echo "Creation of SSH keys cancelled!!!"
    fi
else
    create_and_upload_ssh_key
fi

create_ssh_configuration_file_for_env(){
    \cp -f ssh_configuration ssh_configuration_"$ENVIRONMENT"
    sed -i'.bak' -e "s/#VSERVER-IP/$VSERVER/g" -e "s/#USERNAME/$USERNAME/g" -e "s|#KEYPATH|$SSH_KEY_FOLDER/da_vserver_$ENVIRONMENT|g" ssh_configuration_"$ENVIRONMENT"
    \rm -f  ssh_configuration_"$ENVIRONMENT".bak
}

if test -f "ssh_configuration_$ENVIRONMENT"; then
    if confirm "Do you want to overwrite SSH client settings for $ENVIRONMENT?"; then
        create_ssh_configuration_file_for_env
    fi
else
    create_ssh_configuration_file_for_env
fi

# Include the new configuration file in config of ssh
if ! grep -q "ssh_configuration_$ENVIRONMENT" ~/.ssh/config; then
    echo "# Include the new configuration file in config ..."
    
    sed -i'.bak' '1 i\
Include\ ~\/DeveloperAkademie\/Spielwiese\/vserver\/ssh_configuration_#ENVIRONMENT
' ~/.ssh/config
    sed -i'.bak' "s/#ENVIRONMENT/$ENVIRONMENT/g" ~/.ssh/config
fi

###################################################################
# GIT                                                             #
###################################################################

GIT_USER=$(git config user.name)
GIT_USER_EMAIL=$(git config user.email)

echo "Configure git file..."
sed -i'.bak' -e "s/#GIT_USER/$GIT_USER/g" \
-e "s/#GIT_EMAIL/$GIT_USER_EMAIL/g" remote_files/git_config.sh


###################################################################
# Ansible                                                         #
###################################################################

if confirm "Do you want to setup the server on $ENVIRONMENT?"; then
    echo "Running ansible..."
    # Check if backup file (with placeholders) exists.
    # If the file exists, bla also exists and is already configured.
    if ! test -f "ansible/inventory_$ENVIRONMENT.yml.bak"; then
        rm -rf ansible/inventory_"$ENVIRONMENT".yml
        mv ansible/inventory_"$ENVIRONMENT".yml.bak ansible/inventory_"$ENVIRONMENT".yml
    fi

    # Replace placeholder for V-SERVER IP in inventory-File
    # Creates a backup of original inventory file
    sed -i'.bak' "s/#VSERVER-IP/$VSERVER/g" ansible/inventory_"$ENVIRONMENT".yml
    cd ansible && ansible-playbook -i inventory_"$ENVIRONMENT".yml playbook.yml -K  
else
    echo "Setup of $ENVIRONMENT environment cancelled!!!"
fi