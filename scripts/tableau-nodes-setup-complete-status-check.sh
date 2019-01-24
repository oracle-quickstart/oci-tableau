#!/bin/bash
set -x
hostname
while [ ! -f /tmp/complete ]
do
  sleep 60s
  echo "Waiting for tableau node: $hostname initialization to complete ..."
done

