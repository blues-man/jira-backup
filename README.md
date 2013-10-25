jira-backup
===========

A tool for on-demand jira backups with cURL, suitable for fresh Mac OS X enviroments (and many others)

usage: ./jira_backup.sh [--force, --debug, --help] 

      --force : Skip remote backup procedure, forcing to download it directly
      --debug : Verbose cURL output
      --help  : Print an help

Fill empty and template var to configure the script, and if you don't want email notifications, change

SKIP_MAIL=1
