#!/bin/bash
#Dialog-based script, manages remote nginx
#Requires ssh, ansible, dialog
#Tested on RedOS Release MUROM (7.3.4) 64-bit Kernel Linux 6.1.52-1.el7.3.x86_64 x86_64
#Created by Silaev D.

#Progress bar imitation
#Just for fun :)
randomnum1=1
randomnum2=10
#Loop-based progress bar with random percentage
while [ $randomnum2 -le 100 ]
do
        sleep 0.1
        shuf -i "$randomnum1"-"$randomnum2" -n 1 | dialog --title "Please wait..." --gauge "" 5 50 0
        randomnum1=$randomnum2
        randomnum2=$[$randomnum2 + 10 ]
        sleep 0.2
done
clear

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

#Last log line function
function ENDLOGFILE(){
			echo "----------End of $DATEVAR log----------" >> $LOG_FILE
			echo "" >> $LOG_FILE
}

#Trap for interruptions
trap "echo Interrupt signal by user. >> $LOG_FILE" SIGHUP SIGINT SIGTERM

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
		ENDLOGFILE
		clear && exit;;
	255)
		#Script aborted
		echo "Script was aborted" >> $LOG_FILE
		ENDLOGFILE
		clear && exit;;
esac

#Reminds to configure /etc/ansible/hosts	NOT USED
#dialog --title "Reminder" --msgbox "Make sure you have configured \nyour /etc/ansible/hosts\n\nAll empty strings, comments and\nstrings starting with [\nwill be ignored.\n\nPlaybooks aplly to all hosts\nspecified at /etc/ansible/hosts" 15 40

#Asks if you want to check /etc/ansible/hosts
dialog --title "Reminder" --yesno "Make sure you have configured \nyour /etc/ansible/hosts\n\nAll empty strings, comments and\nstrings starting with [\nwill be ignored.\n\nPlaybooks aplly to all hosts\nspecified at /etc/ansible/hosts\n\n Do you want to check it now?" 15 40
case $? in
        0)
		dialog --textbox /etc/ansible/hosts 100 200
		#Script continues
                clear;;
        1)
                #Script continues without showing hosts
                clear;;
        255)
                #Script aborted
                echo "Script was aborted" >> $LOG_FILE
                ENDLOGFILE
                clear && exit;;
esac

#Running dialog with options
cmd=(dialog --separate-output --colors --title "Options" --checklist "Please select options" 20 50 15)
options=(1 "Check if hosts are available" ON
	 2 "Generate new ssh-key" off
	 3 "Distribute ssh-key to all hosts" ON
	 4 "Check available space" ON
	 5 "Install nginx on remote host" ON
	 6 "Backup remote nginx.conf" ON
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
			#Primary ping function
			function PINGHOST(){
			#Creates temporary file
			OUTPUT="/tmp/output.txt"
			touch "/tmp/output.txt"
			#Input host dialog
			dialog --inputbox "Please enter host" 15 30 2>$OUTPUT
			response=$?

			#Function for Not OK
			function pingnotok(){
			        echo "Not OK!"
				echo "$HOSTADDR is not available" >> $LOG_FILE
				sleep 2
			        rm -f $OUTPUT
				clear
				dialog --title "Ping failed!" --clear --yesno "Remote host is not available.\nWould you like to continue?" 10 36
				case $? in
				        0)
				                #Script continues
						PINGAGAIN
			        	        clear;;
				        1)
			                	#Script aborted
				                echo "Pinging host failed. Script was aborted" >> $LOG_FILE
				                ENDLOGFILE
				                clear && exit;;
				        255)
				                #Script aborted
				                echo "Script was aborted" >> $LOG_FILE
				                ENDLOGFILE
				                clear && exit;;
				esac
			}
			#Function for OK
			function pingok(){
			        echo "OK!"
				echo "$HOSTADDR is available." >> $LOG_FILE
				sleep 2
			        rm -f $OUTPUT
				PINGAGAIN
				clear
			}
			#Ping function
			function PINGREMOTEHOST(){
				clear
                                HOSTADDR=$(cat $OUTPUT)
                                echo "Pinging $HOSTADDR"
                                ping $HOSTADDR -c 4 2> /dev/null > /dev/null && pingok || pingnotok
#				PINGAGAIN
#		                dialog --title "" --clear --yesno "Do you want to ping another host?" 10 36
#                                case $? in
#                                        0)
#                                                #Remote host ping restarts
#						PINGHOST
#                                                clear;;
#                                        1)
#                                                #Script continues
#                                                clear;;
#                                        255)
#                                                #Script aborted
#                                                echo "Script was aborted" >> $LOG_FILE
#                                                ENDLOGFILE
#                                                clear && exit;;
#				esac
			}
			#Repeat option dialog
			function PINGAGAIN(){
                                dialog --title "" --clear --yesno "Do you want to ping another host?" 10 36
                                case $? in
                                        0)
                                                #Remote host ping restarts
                                                PINGHOST
                                                clear;;
                                        1)
                                                #Script continues
                                                clear;;
                                        255)
                                                #Script aborted
                                                echo "Script was aborted" >> $LOG_FILE
                                                ENDLOGFILE
                                                clear && exit;;
                                esac

			}

			case $response in
			        0)
			                PINGREMOTEHOST
			                ;;
			        1)
			                clear
			                echo "Cancel pressed."
			                sleep 2
			                rm -f $OUTPUT
			                clear;;
			        255)
			                clear
			                echo "Script was aborted" >> $LOG_FILE
					ENDLOGFILE
			                echo "[ESC] key pressed, aborting script."
			                sleep 2
			                rm -f $OUTPUT
			                clear && exit;;
			esac
			}

			#Runs primary ping function.
			PINGHOST
			;;
		2)
			#Generating ssh-key
			ssh-keygen -C "$(whoami)@$(hostname)-$(date -I)" &&
			echo "New ssh-key generated." >> $LOG_FILE
			sleep 2 && clear
			;;
		3)
			INPUTFILE="/etc/ansible/hosts"
			OUTPUTFILE="/tmp/temp_hosts"
			IFS=$'\n'

			#Deletes all strings starting with "#" and "[" and empty strings
			#Results are stored in OUTPUTFILE
			touch $OUTPUTFILE
			sed -e '/^#\|^$\| *#/d' -e '/^\[/d' $INPUTFILE > $OUTPUTFILE
			#Distributes ssh-key to all addresses in /etc/ansible/hosts
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
		4)
	                #Check if Ansible is installed
                        echo "Checking if Ansible is installed."
                        dnf list installed | grep ansible >> /dev/null && ans_installed=yes
                        if [ "$ans_installed" == yes ]
                                then
                                        #If Ansible is installed
                                        echo "Ansible is installed." &&
                                        echo "Ansible is installed." >> $LOG_FILE

					INPUTFILE="/etc/ansible/hosts"
					OUTPUTFILE="/tmp/temp_hosts"
		                        IFS=$'\n'
		                        #Deletes all strings starting with "#" and "[" and empty strings
                		        #Results are stored in OUTPUTFILE
		                        touch $OUTPUTFILE
                		        sed -e '/^#\|^$\| *#/d' -e '/^\[/d' $INPUTFILE > $OUTPUTFILE
		                        for IPADDRESS in $(cat $OUTPUTFILE)
        		                do
                        		        echo "Checking disk space for $IPADDRESS"
						touch "$RUN_PATH"/temp_host_df
		                                ansible $IPADDRESS -a "df -h" > "$RUN_PATH"/temp_host_df
						dialog --textbox "$RUN_PATH"/temp_host_df 100 200
						rm "$RUN_PATH"/temp_host_df
						echo "Checked disk space for $IPADDRESS" >> $LOG_FILE
		                                sleep 2 && clear
                		        done
                                else
                                        #If Ansible is not installed
                                        echo "Ansible is not installed, please install and retry." &&
                                        echo "Ansible is not installed, please install and retry." >> $LOG_FILE
                                        sleep 5
                        fi;;
		5)
			#Check if Ansible is installed
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
					echo "Ansible is not installed, please install and retry." &&
					echo "Ansible is not installed, please install and retry." >> $LOG_FILE
					sleep 5
			fi;;
		6)
			#Check if Ansible is installed
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
                                        echo "Ansible is not installed, please install and retry." &&
                                        echo "Ansible is not installed, please install and retry." >> $LOG_FILE
                                        sleep 5
                        fi;;
		10)
			less $LOG_FILE;;
	esac
done
ENDLOGFILE
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

