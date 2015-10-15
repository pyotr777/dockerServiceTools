#!/bin/bash

# Uninstall Docker IaaS tools.
# Need to be run with root privileges.
#
#  Created by Peter Bryzgalov
#  Copyright (C) 2015 RIKEN AICS. All rights reserved

version="0.31a11"
debug=1

if [[ $(id -u) != "0" ]]; then
	printf "Error: Must be root to use it.\n" 1>&2
	exit 1
fi

source ./install.sh -c
if [ ! -f "$diaasconfig" ]; then
	echo "Configuration file not found. DIaaS may not have been installed."
	exit 1
fi
source $diaasconfig

deleteFile() {
	file=$1
	if [ -f "$file" ]; then
		echo -n "Delete $file? [y/n]"
		read -n 1 delfile
		printf "\n"
		if [[ $delfile != "y" ]]; then
			printf "Bye!\n"
			exit 0
		fi
		rm -rf $file
		if [[ $? -eq 1 ]]; then
			echo "Error: Could not delete $file." 1>&2
			exit 1
		fi
		printf "$format" "$file" "deleted"
	fi
}

deleteUser() {
	username=$1
	./cleanuser.sh $username
	printf "$format" "User $username" "deleted"
}

# Delete users
users=$(cat $usersfile | wc -l)
if [ $users -ge 1 ]; then
	echo -n "Delete Docker IaaS users? [y/n]"
	read -n 1 rmusers
	printf "\n"
	if [[ $rmusers == "y" ]]; then
		mapfile -t userlines <<< "$(cat $usersfile)"
		for userline in "${userlines[@]}"; do
			read -ra userarray <<< "$userline"
			deleteUser ${userarray[0]}
		done
	fi
fi
printf "$format" "Users deleted" "OK"

# Group 
if [ -n "$(cat /etc/group | grep "$diaasgroup:")" ]; then
	echo -n "Remove $diaasgroup? [y/n]"
	read -n 1 rmgroup
	printf "\n"
	if [[ $rmgroup != "y" ]]; then
		printf "Bye!\n"
		exit 0
	fi
	groupdel "$diaasgroup"
	printf "$format" "Group $diaasgroup"  "deleted"
fi

# Remove files
deleteFile "$forcecommand" 
printf "$format" "$forcecommand"  "deleted"
deleteFile "$forcecommandlog"
printf "$format" "$forcecommandlog"  "deleted"
if [ -d "$tablesfolder" ]; then 
	deleteFile "$tablesfolder" 
	printf "$format" "$tablesfolder"  "deleted"
fi

# Edit SSH config file
if [ -f "$ssh_conf" ]; then
	if grep -q "$diaasgroup" "$ssh_conf"; then
		if [ -f "tmp_$sshd_config_patch" ]; then
			patch -R "$ssh_conf" < "tmp_$sshd_config_patch"
			if [[ $? -eq 1 ]]; then
				echo "Error: Could not patch $ssh_conf." 1>&2
				exit 1
			fi
			rm "tmp_$sshd_config_patch"
			printf "$format" "Unpatch $ssh_conf" "OK"
		fi
	fi
else
	echo "Error: SSH configuration file $ssh_conf not found." 1>&2
	exit 1
fi

# Edit /etc/pam.d/sshd
if [ -n "$sshd_pam_edited" ]; then
	sed -ri 's/^session\s+optional\s+pam_loginuid.so$/session    required      pam_loginuid.so/' "$sshd_pam"
	if [[ $? -eq 0 ]]; then
		printf "$format"  "$sshd_pam" "edited"
		echo "(session optional pam_loginuid.so -> session required pam_loginuid.so)"
	fi
fi

echo "Restart sshd? [y/n]"
read -n 1 restartssh
printf "\n"
if [[ $restartssh == "y" ]]; then
	service ssh restart			
fi

# Remove DIaaS config file
rm $diaasconfig
printf "$format" "Configuration file $diaasconfig" "deleted"

echo "Uninstallation comlete."
