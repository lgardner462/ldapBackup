#!/bin/bash

cmd=$_
dest_flag=false;
domail=false;
emailAddr="";
status=0
counter=1
dateDir=$(date '+%w')
fullDate=$(date '+%Y/%m/%d')
if [[ $EUID -ne 0 ]];then
	echo "Script must be run as root"
	exit 1
fi

while getopts "d:m" opt; do
	case $opt in
	              
		m)
			domail=true;
			;;
		d)	
			backupFilePath=$OPTARG;	
			dest_flag=true;
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an arguement." >&2
			exit 1
			;;
		esac
done

fullpath=$backupFilePath"/"$dateDir

if [ $dest_flag = false ];then
{	
	echo "-d flag (destination) is required!"
	exit 1
}
else
{
	if [ ! -d "$backupFilePath" ];then
	{
		echo "-d flag requires a valid directory! $backupFilePath does not exist!"
		exit 1	
	}
	else
	{
		if [ ! -d $fullpath ];then 
		{			
		mkdir $fullpath
 		}		
		fi	
	}	
	fi
}
fi

logfile=$(mktemp -p /tmp/ -t $(date '+%w-%m%d%y').XXXXX );
status=$(expr $status \| $?)

if [ $status != 0 ];then
{
	echo "Failed to create log file in /tmp/";
	exit 1;
}
else
{
	echo "Successfully created log file in /tmp/" >> $logfile
}
fi;

	


#backup config
backupConfig=$( slapcat -b cn=config -l "$fullpath/"config-$(date '+%w')-attempt.ldif >> $logfile 2>&1)
status=$(expr $status \| $?)
if [ $status -ne "0" ];then
{
	echo "Failed to slapcat ldap config database to "$fullpath >> $logfile
	rm "$backupFilePath/$dateDir/"config-$(date '+%w')-attempt.ldif
}
else
{
	echo "Successfully slapcat'd ldap config database to "$fullpath >> $logfile
	mv "$fullpath/"config-$(date '+%w')-attempt.ldif "$fullpath/"config-$(date '+%w').ldif
}
fi;
#get ldap db suffixes and loop through them with slapcat
dbSuffixes=$( slapcat -b cn=config | grep "^olcSuffix" | cut -d " " -f2- );
for i in $dbSuffixes;do
	backupDBs=$(slapcat -b $i -l "$fullpath/"ldap$counter-$(date '+%w')-attempt.ldif >> $logfile 2>&1);
done;
status=$(expr $status \| $?)

if [ $status -ne 0 ];then
{
	for i in $dbSuffixes;do
	echo "Failed to slapcat for non-config ldap databases to "$fullpath>> $logfile
	rm "$fullpath/"ldap$counter-$(date '+%w')-attempt.ldif
	done;
	counter=$(($counter +1))
}
else
{
	for i in $dbSuffixes;do
	echo "Successfully slapcat'd for all non-config ldap databases to "$fullpath >> $logfile
	mv -f "$fullpath/"ldap$counter-$(date '+%w')-attempt.ldif "$fullpath/"ldap$counter-$(date '+%w').ldif
	counter=$(($counter + 1))
	done;
}
fi




if [ $domail = true ]; then
{
	if [ $status -ne 0 ];then 
	{
		cat $logfile | mail -s "$cmd  FAIL $fullDate" lgardner@techsquare.com
	}
	else
	{
		cat $logfile | mail -s "$cmd  SUCCESS $fullDate" lgardner@techsquare.com
	}
	fi
}
else
{
	cat $logfile
	echo EXIT STATUS $status
}
fi
rm $logfile
exit $status;
