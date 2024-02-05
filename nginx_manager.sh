#!/bin/bash
#Dialog-based script, manages remote nginx
#Requires ssh, ansible, dialog
#Tested on RedOS Release MUROM (7.3.4) 64-bit Kernel Linux 6.1.52-1.el7.3.x86_64 x86_64
#Created by Silaev D.

#Check if id is root
ID_VAR=$(id -u)
if [ $ID_VAR -ne 0 ]
then
	echo "Must run as root!"
else

#Path to directory where this script is located
RUN_PATH="$(cd "$(dirname $0)" && pwd)"

#Create log file
touch "$RUN_PATH"/nginx_manager.log
LOG_FILE="$RUN_PATH"/nginx_manager.log

#Create date var for logs
DATEVAR=$(date "+%D %H:%M:%S")
echo "----------Start of $DATEVAR log----------" >> $LOG_FILE

#Install dialog
dnf install dialog -y >> /dev/null

#Start dialog
dialog --title "Remote nginx manager" --clear \
	--yesno "Would you like to continue?" 5 31
case $? in
	0)
		#Script continues
		clear;;
	1)
		#Script aborted
		echo "Script was aborted" >> $LOG_FILE
		echo "----------End of $DATEVAR log----------" >> $LOG_FILE
		clear && exit;;
	255)
		#Script aborted
		echo "Script was aborted" >> $LOG_FILE
		echo "----------End of $DATEVAR log----------" >> $LOG_FILE
		clear && exit;;
esac

#Reminds to configure /etc/ansible/hosts
#dialog --title "Reminder" --msgbox "Make sure you have configured \nyour /etc/ansible/hosts\n\nAll empty strings, comments and\nstrings starting with [\nwill be ignored.\n\nPlaybooks aplly to all hosts\nspecified at /etc/ansible/hosts" 15 40

#Asks if you want to check /etc/ansible/hosts
dialog --title "Reminder" --yesno "Make sure you have configured \nyour /etc/ansible/hosts\n\nAll empty strings, comments and\nstrings starting with [\nwill be ignored.\n\nPlaybooks aplly to all hosts\nspecified at /etc/ansible/hosts\n\n Do you want to check it now?" 15 40
case $? in
        0)
		dialog --textbox /etc/ansible/hosts 100 200
		#Script continues
                clear;;
        1)
                #Script aborted
                echo "Script was aborted" >> $LOG_FILE
                echo "----------End of $DATEVAR log----------" >> $LOG_FILE
                clear && exit;;
        255)
                #Script aborted
                echo "Script was aborted" >> $LOG_FILE
                echo "----------End of $DATEVAR log----------" >> $LOG_FILE
                clear && exit;;
esac

#Running dialog with options
cmd=(dialog --separate-output --title "Options" --checklist "Please select options" 20 50 15)
options=(1 "Generate ssh-key" off
	 2 "Distibute ssh-key to all hosts" ON
	 3 "Install nginx on remote host" ON
	 4 "Backup remote nginx.conf" ON
#	 5 "" off
#	 6 "" off
#	 7 "" off
#	 8 "" off
#	 9 "" off
 	 10 "Show log" on)

choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
clear
for choice in $choices
do
	case $choice in
		1)
			#Generating ssh-key
			ssh-keygen -C "$(whoami)@$(hostname)-$(date -I)" &&
			echo "New ssh-key generated." >> $LOG_FILE
			sleep 2 && clear
			;;
		2)
			INPUTFILE="/etc/ansible/hosts"
			OUTPUTFILE="/tmp/temp_hosts"
			IFS=$'\n'

			#Deletes all strings starting with "#" and "[" and empty strings
			#Results are stored in OUTPUTFILE
			touch $OUTPUTFILE
			sed -e '/^#\|^$\| *#/d' -e '/^\[/d' $INPUTFILE > $OUTPUTFILE
			#Distibutes ssh-key to all addresses in /etc/ansible/hosts
			#Pinging them to check 
			for IPADDRESS in $(cat $OUTPUTFILE)
			do
			        echo "Distributing ssh-key to $IPADDRESS"
			        ssh-copy-id root@"$IPADDRESS" 2> /dev/null
			        echo "Pinging $IPADDRESS"
			        ansible -m ping $IPADDRESS &&
				echo "$IPADDRESS successfully pinged" >> $LOG_FILE
				sleep 2 && clear
			done
			;;
		3)
			#Check if Ansbile is installed
			echo "Checking if Ansible is installed."
			dnf list installed | grep ansible >> /dev/null && ans_installed=yes
			if [ "$ans_installed" == yes ]
				then
					#If Ansible is installed
					echo "Ansible is installed." &&
					echo "Ansible is installed." >> $LOG_FILE

					#Launch nginx.yml playbook
					ansible-playbook "$RUN_PATH"/nginx.yml --ask-pass && 
					echo "Nginx is installed and running." >> $LOG_FILE ||
                                        #If ansible failed
                                        echo "Nginx installation failed!" >> $LOG_FILE
					sleep 2
					clear
				else 
					#If Ansible is not installed
					echo "Ansbile is not installed, please install and retry." &&
					echo "Ansible is not installed, please install and retry." >> $LOG_FILE
					sleep 5
			fi;;
		4)
			#Check if Ansbile is installed
			echo "Checking if Ansible is installed."
                        dnf list installed | grep ansible >> /dev/null && ans_installed=yes
                        if [ "$ans_installed" == yes ]
                                then
                                        #If Ansible is installed
                                        echo "Ansible is installed." &&
                                        echo "Ansible is installed." >> $LOG_FILE

					#Launch nginx_conf_bkp.yml playbook
		                        ansible-playbook "$RUN_PATH"/nginx_conf_bkp.yml --ask-pass &&
                                        echo "Remote nginx.conf was backuped." >> $LOG_FILE ||
                                        #If ansible failed
                                        echo "Remote nginx.conf backup has failed!" >> $LOG_FILE
                                        sleep 2
                                        clear
                                else
                                        #If Ansible is not installed
                                        echo "Ansbile is not installed, please install and retry." &&
                                        echo "Ansible is not installed, please install and retry." >> $LOG_FILE
                                        sleep 5
                        fi;;
		10)
			less $LOG_FILE;;
	esac
done
echo "----------End of $DATEVAR log----------" >> $LOG_FILE
echo "" >> $LOG_FILE
echo "Please check $LOG_FILE for more info"
fi

#		vvv NOT USED OPTIONS, CREATED FOR TESTING vvv
#
#		2)
#			#Backups local file
#                        BACKUPEDFILE="$RUN_PATH"/test_1
#                        if [[ -f $BACKUPEDFILE ]];
#                                then
#                                        cp $BACKUPEDFILE "$BACKUPEDFILE"_bkp
#                                        printf "File $BACKUPEDFILE backuped succesfully.\nNew file "$BACKUPEDFILE"_bkp was created!" &&
#                                                echo "File $BACKUPEDFILE backuped succesfully. New file "$BACKUPEDFILE"_bkp was created!" >> $LOG_FILE
#                                        sleep 5
#                                        clear
#                                else
#                                        echo "$BACKUPEDFILE not found!" &&
#                                                echo "$BACKUPEDFILE not found!" >> $LOG_FILE
#                                        sleep 5
#                                        clear
#                        fi;;
#
#                3)
#                        #Backups local nginx.conf
#                        if ( cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf_bkp 2> /dev/null );
#                                then
#                                        echo "nginx.conf was backuped" && echo "nginx.conf was backuped" >> $LOG_FILE
#                                else
#                                        echo "nginx.conf was NOT backuped" && echo "nginx.conf was NOT backuped" >> $LOG_FILE
#                        fi;;

