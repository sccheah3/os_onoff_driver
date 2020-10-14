#! /bin/bash

DRIVES_LOG_FILE=/root/drives.log
STOR_LOG_FILE=/root/storcli_drives.log 
ONOFF_LOG_FILE=/root/onoff.log
ERROR_LOG_FILE=/root/error.log

DRIVES_DIFF_LOG=/root/drives_DIFF.log
STOR_DIFF_LOG=/root/storcli_drives_DIFF.log

printf '\e[1;31m%-6s\e[m' "Press any key to halt this cycle." > /dev/tty0
echo ""

read -t 10 -n 1 < /dev/tty0
if [ $? = 0 ]; then
	echo "Halting cycle" > /dev/tty0
	exit 1
fi


# check if mpt3sas driver is loaded during bootup
lsmod | grep mpt3sas
if [ $? -eq 0 ] ; then
	echo "mpt3sas driver was loaded during bootup. Exiting." > /dev/tty0
	exit 2
fi



modprobe mpt3sas
if [ $? -ne 0 ] ; then
	echo "$( date ) : Error loading mpt3sas driver" >> $ERROR_LOG_FILE
	printf "Error loading mpt3sas driver.\n"
	exit 2
fi

sleep 20	# give time for driver to setup


if [[ ! -f "$DRIVES_LOG_FILE" || ! -f "$ONOFF_LOG_FILE" || ! -f "$STOR_LOG_FILE" ]] ; then

	if [[ ! -f "$DRIVES_LOG_FILE" ]] ; then
		lsblk > $DRIVES_LOG_FILE
	fi

	if [[ ! -f "$ONOFF_LOG_FILE" ]] ; then
		echo "0: $( date )" > $ONOFF_LOG_FILE
	fi

	if [[ ! -f "$STOR_LOG_FILE" ]] ; then
		storcli /c0 show | grep -i "PD LIST" -A 200 > $STOR_LOG_FILE
	fi

	printf "Power cycling system..." > /dev/tty0
	ipmitool power cycle

	if [[ $? -ne 0 ]] ; then
		echo "$( date ) : ipmitool power cycle command failed" >> $ERROR_LOG_FILE
		printf "ipmitool power cycle command failed\n"
	fi

	exit 3
fi

echo "$( cat $ONOFF_LOG_FILE | wc -l ): $( date )" >> $ONOFF_LOG_FILE

# check for lsblk drive differences
if diff <( lsblk ) $DRIVES_LOG_FILE &> /dev/null ; then
	printf "lsblk pass\n" > /dev/tty0
	# ipmitool power cycle
else
	diff <( lsblk ) $DRIVES_LOG_FILE > $DRIVES_DIFF_LOG
	printf '\e[1;31m%-6s\e[m' "Drive difference detected. Check $DRIVES_DIFF_LOG" > /dev/tty0
	echo ""
	exit 4
fi

# check for storcli show differences
if diff <( storcli /c0 show | grep -i "PD LIST" -A 200 ) $STOR_LOG_FILE &> /dev/null ; then
	printf "storcli pass\n" > /dev/tty0
else
	diff <( storcli /c0 show ) $STOR_LOG_FILE > $STOR_DIFF_LOG
	printf '\e[1;31m%-6s\e[m' "Drive difference detected. Check $STOR_DIFF_LOG" > /dev/tty0
	echo ""
	exit 5
fi

printf "power cycling system..." > /dev/tty0
ipmitool power cycle

exit 0