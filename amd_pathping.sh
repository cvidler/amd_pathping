#!/usr/bin/env bash
# amd_pathping Main Script
# Chris Vidler - Dynatrace DCRUM SME 2016
#
# Reads destinations file, and produces data data on network routing and loss.
#

#config 
RTMGATE=/usr/adlex/config/config-access.properties
DSTLIST=/usr/adlex/config/pathping_dests.cfg
CFGFILE=/usr/adlex/config/pathping_conf.cfg
BASEDIR=/var/spool/adlex/rtm
MAXTHREADS=4
DEBUG=0

#defaults global config can override
MAXHOPS=10
TESTS=10
INTERVAL=1.0
TIMEOUT=10
MTU=1500


# Start of script - do not edit below
#set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
GREP=`which grep`
SORT=`which sort`
CAT=`which cat`
JOBS=`which jobs`
WC=`which wc`
#MTR=`which mtr`
MTR=/home/data_mine/mtr/mtr
if [ $? -ne 0 ]; then echo -e "fatal MTR not found in path/not installed"; exit 1; fi

#command line parameters
OPTS=1
while getopts ":hdc:l:o:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=1
			;;
		c)
			CFGFILE=$OPTARG
			;;
		l)
			DSTLIST=$OPTARG
			;;
		o)
			BASEDIR=$OPTARG
			;;
		\?)
			OPTS=0 #show help
			echo -e "\e[31m***FATAL:\e[39m Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			echo -e "\e[31m***FATAL:\e[39m argument -$OPTARG requires parameter."
			;;
	esac
done

if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage: $0 [-h] [-l destinationslist] [-c config] [-o outputdir]"
	echo -e "-h This help"
	echo -e "-l Full path to destinations file, default $DSTLIST"
	echo -e "-c Full path to config file, default $CFGFILE"
	echo -e "-o Full path to output directory, default $BASEDIR"
	exit 0
fi


# Some sanity checking of the config parameters above
if [ ! -r "$DSTLIST" ]
then 
	echo -e "\e[31m***FATAL:\e[39m Destinations config list file $DSTLIST not found. Aborting."
	exit 1
fi

if [ ! -r "$CFGFILE" ]
then 
	echo -e "\e[31m***FATAL:\e[39m Global config list file $CFGFILE not found. Aborting."
	exit 1
fi

if [ ! -r "$RTMGATE" ]
then 
	echo -e "\e[31m***FATAL:\e[39m RTMGATE config access file $CFGFILE not found/readable. Aborting."
	exit 1
fi

if [ ! -w "$BASEDIR" ]
then
	echo -e "\e[31m***FATAL:\e[39m Output storage directory $BASEDIR not found or not writeable. Aborting."
	exit 1
fi


# Lets start things
echo -e "pathping-ng amd_pathping script"
echo 


echo -ne "Check rtmgate access permissions: "
echo
TESTRESULT=`$GREP "pathping_\*.cfg" "$RTMGATE"`
if [ "$TESTRESULT" == "" ] 
then
	echo -e "rtmgate config not found, adding..."

	# each line in the file is uniquely numbered, find the last one, and add one
	LASTNUM=`$AWK -F"[.=]" '/ConfigFile/{a=$2}; END {print a};' "$RTMGATE"`
	#echo "[$LASTNUM]"
	NEWNUM=$((LASTNUM + 1))
	#echo "[$NEWNUM]"
	# check for write permissions
	if [ ! -w "$RTMGATE" ] 
	then
		echo -e "\n\e[31m***FATAL:\e[39m rtmgate config $RTMGATE not writeable. Aborting."
		exit 1
	fi
	# add new entry to rtmgate config
	echo -e "ConfigFile.$NEWNUM=pathping_*.cfg\n" >> $RTMGATE
	# restart rtmgate (safe, no outage to monitoring)
	echo -e "Restarting RTMGATE daemon to enable change"
	`systemctl restart rtmgate`
else
	echo "OK"
fi


echo -e "Loading global configuration from config file: $CFGFILE"
echo

#read global config file
IFS="=";
while read a v; do
	#echo -e "$a:$v"
	case "${a,,}" in
		timeout)
			TIMEOUT=$v
			;;
		interval)
			INTERVAL=$v
			;;
		maxhops)
			MAXHOPS=$v
			;;
		count)
			TESTS=$v
			;;
		maxmtu)
			MTU=$v
			;;
		\#*|'')
			#comment/blank lines
			;;
		*)
			echo -e "\e[33m***WARNING:\e[39m Ignoring unknown config line: $a"
			;;
	esac
done < $CFGFILE
IFS=$',\n\t'

#mtr needs root for intervals below 1 second, check the config and if root or not.
#if (( $(echo "$INTERVAL < 1.0" | bc -l) )); then
#	if [ $EUID -ne 0 ]; then
#		echo -e "\e[31m***FATAL:\e[39m <1.0 sec Interval requires root."
#		exit 1
#	fi
#fi

#display global configs
echo -e "  Timeout:  $TIMEOUT"
echo -e "  Interval: $INTERVAL"
echo -e "  Max Hops: $MAXHOPS"
echo -e "  Tests:    $TESTS"
echo -e "  Max MTU:  $MTU"
echo 


#display destinations from config file
echo -e "Loading destinations to test from config file: $DSTLIST"
echo
echo -e "`$AWK -F"," '$1=="A" { print " + " $2 "" } ' $DSTLIST`"
echo -e "\e[2m`$AWK -F"," '$1=="D" { print " - " $2 " Disabled" } ' $DSTLIST`\e[0m"
echo

TIMESTAMP=`date -d "\`date -u +"%Y-%m-%d %H:00:00"\`" +%s` ; TIMESTAMP=`printf "%x" $TIMESTAMP`
if [ $DEBUG -ne 0 ]; then echo -e "\e[36m***DEBUG: TIMESTAMP=$TIMESTAMP \e[39m"; fi
OUTFILE="$BASEDIR/pathping_${TIMESTAMP}_e10_t"
if [ $DEBUG -ne 0 ]; then echo -e "\e[36m***DEBUG: OUTFILE=$OUTFILE \e[39m"; fi
SRC=`ip addr | grep "state UP" -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'` 
if [ $DEBUG -ne 0 ]; then echo -e "\e[36m***DEBUG: SRC=$SRC \e[39m"; fi

#output header data to file if not already existing
if [ ! -r $OUTFILE ]; then echo "#ts src dst hop host loss% rcv snt best avg worst" > $OUTFILE; fi

#iterate through active destinations testing them.
$AWK -F"," '$1 ~ /^[Aa]/ { print $2 } ' $DSTLIST | ( while read p; do 

	#pause while thread count high
	while [ $($JOBS -r | $WC -l) -ge $MAXTHREADS ]; do sleep 1; done

	#start test (as a background subshell)
	(
	echo -e "Performing testing for destination: ${p}"
	TMPFILE=`mktemp`
	if [ $DEBUG -ne 0 ]; then echo -e "\e[36m***DEBUG: PID=$BASHPID DEST=$p TMPFILE=$TMPFILE \e[39m"; fi
	TS=`date -u +%s`; TS=`printf "%x" $TS`
	sudo $MTR --no-dns --timeout=$TIMEOUT --report-cycles=$TESTS --interval=$INTERVAL --max-ttl=$MAXHOPS --psize=-$MTU --split ${p} > $TMPFILE
	$CAT $TMPFILE | $SORT -g -k 1,1 -k 4,4 | $AWK -F" " -v ts="$TS" -v src="$SRC" -v dst="$p" ' BEGIN { p = $1 } { if (p != $1) { print ts,src,dst,old }; old = $0; p = $1 } END { print ts,src,dst,old } ' | $AWK ' NF > 3 ' >> $OUTFILE
	rm $TMPFILE
	) &

done; wait
)

#complete
echo
echo -e "pathping-ng amd_pathping script complete"
echo
if [ $DEBUG -ne 0 ]; then echo -e "\e[36m***DEBUG: Output follows:"; cat $OUTFILE; echo -e "\e[39m"; fi


