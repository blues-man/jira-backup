#!/bin/bash
# A jira backup utility based on cURL, suitable for fresh Mac Enviroments (and many others!)
# usage: ./jira_backup.sh [--force, --debug, --help] 
# --force : Skip remote backup procedure
# --debug : Verbose cURL output
# --help  : Print an help
# Author: Natale Vinto<ebballon@gmail.com> 
# based on Atlassian wget based script https://confluence.atlassian.com/display/ONDEMANDKB/Automatic+backups+for+JIRA+OnDemand

USERNAME=""
PASSWORD=""
INSTANCE=".atlassian.net"
LOCATION=`pwd`

EMAIL_NOTIFICATION="foo@domain.tld"
EMAIL_DOMAIN="domain.tld"

OPTION=$1
SKIP_BACKUP=0
SKIP_MAIL=1
DEBUG=0

TODAY=`date +%Y%m%d`


if [ "$OPTION" = "--force" ]; then
	SKIP_BACKUP=1;
elif [ "$OPTION" = "--help" ]; then
	echo "Usage: jira_backup.sh        # Remote backup and download"
	echo "	   : jira_backup.sh --force # Skip backup procedure and download only ZIP"
	exit
elif [ "$OPTION" = "--debug" ]; then
	DEBUG=1
fi	

if [ "$2" = "--debug" ]; then
	DEBUG=1
fi


SILENT="-s"

if [ $DEBUG -eq 1 ]; then
	SILENT=""
fi 


function send_mail() {

if [ $SKIP_MAIL -eq 1 ]; then
  	return 0
fi
STATUS=$1
DATE=$(date)
SUBJECT="[${STATUS}] Jira Backup system on $DATE"
BODY=$2

sendmail "$EMAIL_NOTIFICATION" <<EOF
subject:$SUBJECT
from:jira@$EMAIL_DOMAIN
$BODY
EOF

}

# Grabs cookies and generates the backup on the UI. 
urlresp=""
if [ $SKIP_BACKUP -eq 0 ]; then
	echo "Backuping..."
	COOKIE_FILE_LOCATION=jiracookie
	curl $SILENT -u $USERNAME:$PASSWORD --cookie-jar $COOKIE_FILE_LOCATION https://${INSTANCE}/Dashboard.jspa --output /dev/null
	BKPMSG=`curl $SILENT --cookie $COOKIE_FILE_LOCATION --header "X-Atlassian-Token: no-check" -H "X-Requested-With: XMLHttpRequest" -H "Content-Type: application/json"  -X POST https://${INSTANCE}/rest/obm/1.0/runbackup -d '{"cbAttachments":"true" }' `
	rm $COOKIE_FILE_LOCATION
 	
	#Checks if the backup procedure has failed
	if [ `echo $BKPMSG | grep -i backup | wc -l` -ne 0 ]; then
		send_mail "WARNING" "$BKPMSG"
		echo $BKPMSG
		SKIP_BACKUP=1
	fi
fi


#Checks if the backup exists in WebDAV every 10 seconds, 20 times. If you have a bigger instance with a larger backup file you'll probably want to increase that.
echo "Checking backup file availability.."
for (( c=1; c<=20; c++ ))
	do
		# -f option for exit codes != | HTTP >=401
		urlresp=$(curl $SILENT -f -u $USERNAME:$PASSWORD https://${INSTANCE}/webdav/backupmanager/JIRA-backup-${TODAY}.zip -I)
		OK=$?
		if [ $OK -eq 0 -o $SKIP_BACKUP = 1 ]; then
			break
		fi
		sleep 10
	done
 

if [ $OK -ne 0 ]; then
	send_mail "ERROR" "JIRA-backup-${TODAY}.zip not found"
	echo "JIRA-backup-${TODAY}.zip not found"
	exit
else
 	echo "Downloading backup JIRA-backup-${TODAY}.zip ..."
	curl -u $USERNAME:$PASSWORD https://${INSTANCE}/webdav/backupmanager/JIRA-backup-${TODAY}.zip -O $LOCATION 2>/dev/null
	integrity=$(unzip -t $LOCATION/JIRA-backup-${TODAY}.zip)
	if [ $? -eq 0 ]; then
		echo "Backup JIRA-backup-${TODAY}.zip downloaded and file integrity is fine."
		send_mail "OK" "Backup JIRA-backup-${TODAY}.zip downloaded and intact."
	else
		echo "Backup JIRA-backup-${TODAY}.zip corrupted, retry"
		send_mail "ERROR" "Backup JIRA-backup-${TODAY}.zip downloaded with errors."

	fi
fi
