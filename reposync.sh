#!/bin/bash
#Repo sync script for RedOS 7.3
#Requires httpd, createrepo, yum-utils installed and httpd configured.
#
#Checks if id is root
ID_VAR=$(id -u)
if [ $ID_VAR -ne 0 ]
then
	clear
	echo "Must run as root!"
	exit
else
	#Checks if run path is /var/www/html/repo/red-os-7.3
	RUN_PATH="$(cd "$(dirname $0)" && pwd)"
	if [[ $RUN_PATH =~ /var/www/html/repo/red-os-7.3 ]]
	then
		#Continues script
		echo "Current run path is $RUN_PATH"
	else
		#Interrupts script if run path does not match
		echo "Current run path is $RUN_PATH"
		echo "Run this script only from /var/www/html/repo/red-os-7.3 directory!"
		exit
	fi
	read -p "Press \"y or Y\" if you want to continue " -n 1 -r
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
	        #Creates base repo
        	reposync --repoid=base --downloadcomps --download-metadata
	        createrepo -v /var/www/html/repo/red-os-7.3/base -g comps.xml
        	#Creates updates repo
	        reposync --repoid=updates --downloadcomps --download-metadata
        	createrepo -v /var/www/html/repo/red-os-7.3/updates
	        #Creates kernels repo
        	reposync --repoid=kernels6 --downloadcomps --download-metadata
	        createrepo -v /var/www/html/repo/red-os-7.3/kernels6
        	#Restarts httpd service
	        systemctl restart httpd

	else
		clear
	        echo "Aborted."
		exit
	fi


fi
