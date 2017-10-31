#!/bin/bash

REMOTE_USER="mrmakeit"
TWO_FACTOR=true

sudo -v

if [ ! -f $HOME/.config/bootstrap-complete ]; then
  cd /tmp
  mkdir provisioning_files
  cd provisioning_files

  echo "Adding required repositories and upgrading system for first time use"
  if [ ! -z "$TWO_FACTOR" ]; then
    sudo apt-add-repository ppa:yubico/stable
  fi

  sudo apt-get update
  sudo apt-get upgrade

  echo "Installing expected programs"
  sudo apt-get install -y pass xclip wget curl git
  if [ ! -z "$TWO_FACTOR" ]; then
    sudo apt-get install yubikey-manager
  fi

  echo "Installing Keybase"
  wget https://prerelease.keybase.io/keybase_amd64.deb
  sudo dpkg -i keybase_amd64.dev
  sudo apt-get install -f
  run_keybase

  keybase login

  keybase pgp export -s | gpg2 --import

  echo "Grabbing bootstrap password store from keybase"
  git clone keybase://private/$REMOTE_USER/passwords $HOME/.password-store/

  echo "Preloading github credentials"

  GITHUB_USERNAME=$REMOTE_USER
  GITHUB_PASSWORD=$(pass show github) 
  if [ ! -z "$TWO_FACTOR" ]; then
    echo -n "Enter Yubikey Password: " && read -s passwd
    OATH=$(ykman oath -p $passwd code Github | rev | cut -d" " -f1 | rev)
  fi

  echo "Provisioning ssh key"

  if [ ! -f $HOME/.ssh/id_rsa ]; then
    ssh-keygen -b 2048 -t rsa -f $HOME/.ssh/id_rsa -q -N ""
  fi

  curl https://api.github.com/user/keys -X POST -H "X-GitHub-OTP: $OATH" -u $GITHUB_USERNAME:$GITHUB_PASSWORD --data "{\"title\":\"provision for $HOSTNAME\",\"key\":\"`cat $HOME/.ssh/id_rsa.pub`\"}"

  git clone git@github.com:$REMOTE_USER/provision.git $HOME/.provision

else

  sudo apt-get update
  sudo apt-get upgrade

  wget https://prerelease.keybase.io/keybase_amd64.deb
  sudo dpkg -i keybase_amd64.dev
  sudo apt-get install -f
  run_keybase

  pass git pull
  pass git push

  cd $HOME/.provision
  git commit -a
  git pull
  git push

fi
cd $HOME

.provision/apt-installs.sh
.provision/custom-installs.sh
