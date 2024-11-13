#!/bin/bash

if [ ! -d "./ssh" ] || [ ! -f "./ssh/ssh_ed25519_key" ]; then
  echo "this script must be run in the top of the installer directory, not from the scripts dir"
  exit 1
fi

if [ -f "./ssh/interface.txt" ]; then
  INTERFACE=$(cat ./ssh/interface.txt)
  sudo ip address add dev "$INTERFACE" 172.16.42.1/24 &>/dev/null
  sudo ip link set "$INTERFACE" up &>/dev/null
else
  echo "could not find ./ssh/interface.txt - you will have to set the interface up yourself."
fi

ssh -i ./ssh/ssh_ed25519_key -o StrictHostKeyChecking=no root@172.16.42.2
