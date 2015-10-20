#!/bin/bash

#  Creates user with designated key, creates Docker container with user name.
#  Makes set up for automatic user login to the container
#  with SSH and agent forwarding.
#
#  Parameters:
#  user name,
#  file with public SSH key,
#  Docker image name to use for container.
#
#  User and container names are stored in user tabel file (/usertable.txt).
#
#  Use cleanuser.sh with user name for deleting user from server,
#  deleting user record from tabel file and deleting user container.
#
#  Created by Peter Bryzgalov
#  Copyright (C) 2014-2015 RIKEN AICS. All rights reserved

version="0.32a03"
echo "$0 v$version"

# Initialization
if [ $# -lt 1 ]
then
    read -rd '' hlp <<- EOF
	Creates user with designated SSH key, creates Docker image "localhost/username".
	Makes set up for automatic user login to the container
	with SSH and agent forwarding.

	Parameters:
	user name,
	Docker image name to use for container,
	file with public SSH key.
	
	-----
EOF
    printf  "%s\n" "$hlp"
    ./users.sh
    exit 0
fi

if [[ $(id -u) != "0" ]]; then
    printf "Error: Must be root to use it.\n" 1>&2
    exit 1
fi

username=$1
image=$2
public_key_file=$3

source ./install.sh -c
if [ ! -f "$diaasconfig" ]; then
	echo "Configuration file not found. DIaaS may not have been installed."
	exit 1
fi
source $diaasconfig

# In-container locations
container_connections_counter="/tmp/dockeriaas_cc"
container_config="/tmp/dockeriaas_conf"
container_home="/root"
service_folder="service"
service_container_folder="/usr/local/bin"


userExists() {
    awk -F":" '{ print $1 }' /etc/passwd | grep -x $1 > /dev/null
    return $?
}

if [ "$username" = "dockertest" ]
then
    echo "Name dockertest is reserved. Try different user name."
    exit 1
fi

userExists $username
if [ $? = 0 ]
then
    echo "User $username already exists. Try different name."
    exit 1
fi

if [ ! -f $public_key_file ]
then
    echo "Public key file $public_key_file not found."
    exit 1
fi

if [[ -z "$image" ]]
then
    echo "Need Docker image."
    echo "Possible values:"
    docker images | grep -v REPOSITORY | awk '{ print $1 ":" $2 }' 
    exit 1
fi

avail_image=$(docker history $image | grep -i "error")
if [[ -n "$avail_image" ]]
then
    echo "Not found Docker image $image."
    echo "Try one of these:"
    docker images | grep -v REPOSITORY | awk '{ print $1 ":" $2 }' | sed 's/:latest//'
    exit 1
fi

# Create Dockerfile 

read -r -d '' dockerfile_string <<EOF
FROM $image
EXPOSE 22
ENV DEBIAN_FRONTEND noninteractive
RUN locale-gen en_US.UTF-8
RUN apt-get install -y ssh
RUN mkdir -p /var/run/sshd

# Disable pam_loginuid to correct SSH login bug
RUN sed -r -i "s/session\s+required\s+pam_loginuid\.so/session optional pam_loginuid.so/" /etc/pam.d/sshd

# ENV DEBIAN_FRONTEND dialog

RUN mkdir $container_home/.ssh
ADD $public_key_file $container_home/.ssh/authorized_keys
ADD $service_folder/ $service_container_folder/

RUN echo 0 > $container_connections_counter
RUN printf "timeout:2\n" > $container_config
RUN mkdir /logs

# Disable password login
# RUN sed -r -i "s/^.*PasswordAuthentication[yesno ]+$/PasswordAuthentication no/" /etc/ssh/sshd_config

RUN printf "\nForceCommand $service_container_folder/container.sh" >> /etc/ssh/sshd_config
ENV DEBIAN_FRONTEND dialog
CMD ["/usr/sbin/sshd","-D"]
EOF

echo "$dockerfile_string" > Dockerfile

# Build image

docker build -t localhost/$username .

# Remove Dockerfile
rm Dockerfile

# Register user and conatiner names in user table file
echo "$username $username" >> $usersfile

# Create user

useradd -m $username
usermod -a -G $diaasgroup $username
usermod -a -G ssh $username
echo "User $username created on host"

if [ ! -d "/home/$username/.ssh" ]
then
    mkdir -p /home/$username/.ssh
fi
cat $public_key_file > /home/$username/.ssh/authorized_keys
chown -R $username:$username /home/$username/

# Check TCP connection to Docker remote API
# Required for automatic login to container
# default dockercommand = "docker -H localhost:4243"
test=$($dockercommand ps)
if [ -z "$test" ]
then
    echo "ERROR: Cannot connect to Docker API with $dockercommand"
    echo "Restarting socat proxy"
    kill $socatpid
    ./socat-start.sh $dockerport
	if [ ! -f socat.pid ]; then
		printf "$format"  "socat" "failed"
		exit 1
	fi
	socatpid=$(cat socat.pid)
	# Delete file with socat PID
	rm socat.pid
	printf "$format"  "socat" "started with PID $socatpid"
fi
