#!/usr/bin/env bash

if [ ! -d "./ssh" ]; then
  echo "this script must be run in the top of the installer directory, not from the scripts dir"
  exit 1
fi

echo "Setting correct SSH key permissions..."
chmod 600 ./ssh/ssh_ed25519_key
chmod 600 ./ssh/ssh_rsa_key

if [ -f "./ssh/interface.txt" ]; then
  INTERFACE=$(cat ./ssh/interface.txt)

  sudo ifconfig "$INTERFACE" down 2>/dev/null
  sudo ifconfig "$INTERFACE" delete 172.16.42.1 2>/dev/null
  sudo route -n delete 172.16.42.0/24 2>/dev/null

  echo "Configuring interface $INTERFACE..."
  sudo ifconfig "$INTERFACE" 172.16.42.1 netmask 255.255.255.0 up

  echo "Adding route..."
  sudo route -n add 172.16.42.0/24 172.16.42.1

  echo "Interface configuration:"
  ifconfig "$INTERFACE"
  echo "Routing table:"
  netstat -nr | grep 172.16.42
else
  echo "could not find ./ssh/interface.txt - you will have to set the interface up yourself."
fi

if ! ssh -i ./ssh/ssh_ed25519_key -o StrictHostKeyChecking=no root@172.16.42.2; then
  echo "ED25519 key failed, trying RSA key..."
  ssh -i ./ssh/ssh_rsa_key -o StrictHostKeyChecking=no root@172.16.42.2
fi
