#!/bin/bash

nmap -sn $localip.* | grep $localip. | awk '{print $5}' > /home/hpcuser/bin/nodeips.txt

