#!/bin/bash

IPaddr='192.168.255.1'


echo "Start knocking ..."
nc -z -w1 "$IPaddr" 9682 && sleep 1
nc -z -w1 "$IPaddr" 7225 && sleep 1
nc -z -w1 "$IPaddr" 4036 && sleep 1
nc -z -w1 "$IPaddr" 8113

echo "Try to connect via SSH ..."
ssh vagrant@"$IPaddr"

