#!/usr/bin/env bash

if pfctl -sr | grep "172.16.42.0"; then
  echo "pfctl rules exist"
else

  sudo sysctl -w net.inet.ip.forwarding=1

  cat <<EOF >/tmp/pf.conf
nat on en0 from 172.16.42.0/24 to any -> (en0)
pass all
EOF

  sudo pfctl -e

  sudo pfctl -F all -f /tmp/pf.conf

  rm /tmp/pf.conf
fi
