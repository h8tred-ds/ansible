#!/bin/bash
#Dialog-based script, manages remote nginx
#Requires ssh, ansible, dialog
#Tested on RedOS Murom 7.3.4
#Created by Silaev D.
#Version 2.0

#Progress bar imitation
randomnum1=1
randomnum2=10
while [ $randomnum2 -le 100 ]
do
	sleep 0.1
	shuf -i "$randomnum1"-"$randomnum2" -n 1 | dialog --title "Please wait..." --gauge "" 5 50 0
	randomnum1=$randomnum2
	randomnum2=$[$randomnum2 + 10 ]
	sleep 0.2
done
#clear

#Check if id is root
ID_VAR=$(id -u)
if [ $ID_VAR -ne 0 ]
then
	clear
	echo "Must run as root!"
	exit
else
	#Path to script location
	RUN_PATH="$(cd "$(dirname $0)" && pwd)"

	#Log file
	touch "$RUN_PATH"/nginx_manager.log
	LOG_FILE="$RUN_PATH"/nginx_manager.log

	#Date var for logs
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

	#Check if Ansible is installed
	#echo "Checking if Ansible is installed."
	dialog --infobox "Checking if Ansible is installed." 10 31
	if ( dnf list installed | grep ansible >> /dev/null )
	then
		#echo "Ansible is installed."
		dialog --infobox "Ansible is installed." 10 31
		sleep 2

		#Start yesno dialog
		dialog --title "Remote nginx manager" --clear \
		--yesno "Would you like to continue?" 10 31
		case $? in
			0)
				#Yes chosen. Script continues
				clear;;
			1)
				#No chosen. Script aborted
				echo "Script was aborted." >> $LOG_FILE
				ENDLOGFILE
				clear && exit;;
			255)
				#[ESC] pressed. Script aborted
				echo "Script was aborted." >> $LOG_FILE
				ENDLOGFILE
				clear && exit;;
		esac

		#Creating temp ini file with host
		touch /tmp/temp_ini.tmp
		TEMP_INI="/tmp/temp_ini.tmp"
		echo "[target]" > $TEMP_INI

		#Dialog function, asks to input host
		function INPUTHOSTDIALOG(){
        		#Input host dialog
		        touch /tmp/outputhost.tmp
	        	OUTPUTHOST="/tmp/outputhost.tmp"
		        dialog --inputbox "Please enter host" 10 100 2>$OUTPUTHOST
        		echo "$(cat $OUTPUTHOST)" >> $TEMP_INI
			echo "$(cat $OUTPUTHOST) was added to [target]." >> $LOG_FILE
		        rm -f $OUTPUTHOST
		        clear
			ASKFORMOREHOSTS
		}
		
		#Dialog function, asks if you want to input more hosts
		function ASKFORMOREHOSTS(){
			#yesno dialog, asks if you want to add more hosts
			dialog --yesno "Do you want to add another host?" 10 36
			case $? in
				0)
					#Yes chosen. Initiates input host dialog again
					INPUTHOSTDIALOG
					;;
				1)
					#No chosen. Script continues.
					clear
					;;
				255)
					#Script aborted, [ESC] pressed.
					echo "Script was aborted." >> $LOG_FILE
					ENDLOGFILE
					clear && exit;;
			esac

		}


		#Initial input host dialog
		INPUTHOSTDIALOG

		#Asks if you want to continue and everything is ok
		function ISITOK(){
			dialog --title "Confirmation" --yesno "Would you like to continue?\n\nYou may want to abort this script if something went wrong." 15 40
			case $? in
					0)
						#Yes chosen, script continues
						clear;;
					1)
						#No chosen, script aborted
						echo "Script was aborted." >> $LOG_FILE
						ENDLOGFILE
						clear && exit;;
					255)
						#[ESC] pressed, script aborted
						echo "Script was aborted." >> $LOG_FILE
						ENDLOGFILE
						clear && exit;;
			esac
		}

		#Main dialog with options
		cmd=(dialog --separate-output --title "Options" --checklist "Please select options" 20 50 15)
		options=(1 "Generate new ssh-key" off
			2 "Distribute ssh-key" ON
			3 "Check availability" ON
			4 "Check available space" ON
			5 "Install nginx" ON
			6 "Backup nginx.conf" ON
			10 "Show log" ON)
		choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
		clear
		for choice in $choices
		do
			case $choice in
				1)
					#Generates new ssh-key
					#echo "Generating new ssh-key"
					dialog --infobox "Generating new ssh-key..." 10 31
					ssh-keygen -C "$(whoami)@$(hostname)-$(date -I)" &&
					echo "New ssh-key generated." >> $LOG_FILE
					sleep 2
					#clear
					;;
				2)
					#Preparations for key distributing
					INPUTFILE=$TEMP_INI
					OUTPUTFILE="/tmp/temp_hosts"
					touch $OUTPUTFILE
					IFS=$'\n'

					#Deletes all strings starting with "#", "[" and empty strings
					#Results are stored in OUTPUTFILE and deleted after distribution
					sed -e '/^#\|^$\| *#/d' -e '/^\[/d' $INPUTFILE > $OUTPUTFILE
					#Functions for ok-notok distributing
					function distr_ok(){
						#echo "Key distributed to $HOSTADDR successfully."
						dialog --infobox "Key distributed to $HOSTADDR successfully." 10 31
						echo "Key distributed to $HOSTADDR successfully." >> $LOG_FILE
						sleep 2
						#clear
					}
					function distr_notok(){
                                                #echo "Key distribution to $HOSTADDR failed!"
						dialog --infobox "Key distribution to $HOSTADDR failed!" 10 31
                                                echo "Key distribution to $HOSTADDR failed!" >> $LOG_FILE
						sleep 2
						#clear
                                        }
					#Distributes ssh-key to all hosts
					for HOSTADDR in $(cat $OUTPUTFILE)
					do
						#echo "Distributing ssh-key to $HOSTADDR"
						dialog --infobox "Distributing ssh-key to $HOSTADDR" 10 31
						ssh-copy-id root@"$HOSTADDR" 2> /dev/null && distr_ok || distr_notok
						sleep 2
					done
					ISITOK
					;;
				3)
					#Pinging hosts from [target] section of TEMP_INI
					#echo "Checking availability for host(s)."
					dialog --infobox "Checking availability for host(s)." 10 31
					touch "$RUN_PATH"/temp_ping
					sleep 1
					ansible target -m ping -i $TEMP_INI >> "$RUN_PATH"/temp_ping
					dialog --textbox "$RUN_PATH"/temp_ping 100 200
					rm -f "$RUN_PATH"/temp_ping
					sleep 1
					ISITOK
					;;
				4)
					#Checking diskspace for [target] section of TEMP_INI
					#echo "Checking disk space for host(s)."
					dialog --infobox "Checking disk space for host(s)." 10 31
					touch "$RUN_PATH"/temp_df
					ansible target -a "df -h" -i $TEMP_INI >> "$RUN_PATH"/temp_df
					dialog --textbox "$RUN_PATH"/temp_df 100 200
					rm -f "$RUN_PATH"/temp_df
					sleep 1
					ISITOK
					;;
				5)
					#Installing nginx
					touch "$RUN_PATH"/temp_nginx_inst
					dialog --infobox "Installing nginx." 10 31
					ansible-playbook "$RUN_PATH"/nginx.yml -i $TEMP_INI > "$RUN_PATH"/temp_nginx_inst &&
						echo "nginx is installed and running." >> $LOG_FILE ||
						echo "nginx installation partialy failed." >> $LOG_FILE
					dialog --textbox "$RUN_PATH"/temp_nginx_inst 100 200
					rm -f "$RUN_PATH"/temp_nginx_inst
					sleep 1
					clear
					ISITOK
					;;
				6)
					#Backup nginx.conf
					touch "$RUN_PATH"/temp_nginx_bkp
					dialog --infobox "Starting nginx.conf backup." 10 31
					ansible-playbook "$RUN_PATH"/nginx_conf_bkp.yml -i $TEMP_INI > "$RUN_PATH"/temp_nginx_bkp &&
						echo "nginx.conf backup successful." >> $LOG_FILE ||
						echo "nginx.conf backup partialy failed." >> $LOG_FILE
					dialog --textbox "$RUN_PATH"/temp_nginx_bkp 100 200
					rm -f "$RUN_PATH"/temp_nginx_bkp
					sleep 1
					clear
					ISITOK
					;;
				10)
					#less $LOG_FILE
					dialog --textbox "$LOG_FILE" 100 200
					;;
			esac
		done
		
		ENDLOGFILE
		dialog --pause "Finished." 10 31 10
		clear
		#Removing temporary ini file
		rm -f $TEMP_INI
	else
		#echo "Ansible is not installed, please install and try again."
		dialog --pause "Ansible is not installed, please install and try again." 20 50 5
		echo "Ansible is not installed, please install and try again." >> $LOG_FILE
		sleep 2
		clear
		ENDLOGFILE
		exit
	fi
	
fi
