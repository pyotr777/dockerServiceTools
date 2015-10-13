#!/bin/bash

# Uninstall Docker IaaS tools.
# Need to be run with root privileges.
#
#  Created by Peter Bryzgalov
#  Copyright (C) 2015 RIKEN AICS. All rights reserved

version="0.30"
debug=1

if [[ $(id -u) != "0" ]]; then
	printf "Error: Must be root to use it.\n" 1>&2
	exit 1
fi

source ./install.sh -c

deleteFile() {
	file=$1
	if [ -a "$file" ]; then
	echo -n "Delete file $file? [y/n]"
	read -n 1 delfile
	if [[ $delfile != "y" ]]; then
		printf "\nBye!\n"
		exit 0
	fi
	printf "\n%s\t\t\t\t" "$file"
	rm -rf $file
	if [[ $? -eq 1 ]]; then
		printf "\terror.\n"
		echo "Error: Could not delete $file." 1>&2
		exit 1
	fi
	printf "deleted.\n"
fi

}

# Group 

if [ -n "$(cat /etc/group | grep "$diaasgroup:")" ]; then
	echo -n "Remove $diaasgroup? [y/n]"
	read -n 1 rmgroup
	if [[ $rmgroup != "y" ]]; then
		printf "\nBye!\n"
		exit 0
	fi
	groupdel "$diaasgroup"
	printf "\nGroup $diaasgroup\t\tRemoved.\n"
fi

# Remove files

deleteFile "$forcecommand" 
deleteFile "$forcecommandlog"
if [ -d "$tablesfolder" ]; then 
	deleteFile "$tablesfolder" 
fi