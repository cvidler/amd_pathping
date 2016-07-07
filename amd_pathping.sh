# amd_pathping Main Script
# Chris Vidler - Dynatrace DCRUM SME 2016
#
# Reads destinations file, and produces data data on netwokr routing and loss.
#

#config 
DSTLIST=destinations.cfg
CFGFILE=globalconfig.cfg
BASEDIR=/var/spool/amd_pathping
MAXTHREADS=4
DEBUG=0

#defaults global config can override
MAXHOPS=10
TESTS=10
INTERVAL=1.0
TIMEOUT=10
MTU=1500


# Start of script - do not edit below
set -euo pipefail
IFS=$',\n\t'
AWK=`which awk`
JOBS=`which jobs`
WC=`which wc`
MTR=`which mtr`
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
	exit
fi

if [ ! -r "$CFGFILE" ]
then 
	echo -e "\e[31m***FATAL:\e[39m Global config list file $CFGFILE not found. Aborting."
	exit
fi

if [ ! -w "$BASEDIR" ]
then
	echo -e "\e[31m***FATAL:\e[39m Output storage directory $BASEDIR not found or not writeable. Aborting."
	exit
fi


# Lets start things
echo -e "amd_pathping script"
echo 
echo -e "Loading global configuration from config file: $CFGFILE"

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
			echo unknown config line: $a
			;;
	esac
done < $CFGFILE
 
IFS=$',\n\t'

echo -e "  Timeout:  $TIMEOUT"
echo -e "  Interval: $INTERVAL"
echo -e "  Max Hops: $MAXHOPS"
echo -e "  Tests:    $TESTS"
echo -e "  Max MTU:  $MTU"
echo 


echo -e "Loading destinations to test from config file: $DSTLIST"
echo
echo -e "`$AWK -F"," '$1=="A" { print " + " $2 "" } ' $DSTLIST`"
echo -e "\e[2m`$AWK -F"," '$1=="D" { print " - " $2 " Disabled" } ' $DSTLIST`\e[0m"
echo

DODEBUG=""
$AWK -F"," '$1=="A" { print $2 } ' $DSTLIST | ( while read p; do 
	while [ $($JOBS -r | $WC -l) -ge $MAXTHREADS ]; do sleep 1; done
	echo -e "Performing pathping for destination: ${p}"
	if [ $DEBUG -ne 0 ]; then DODEBUG=-d; fi
	#$SCRIPTDIR/archiveamd.sh -n "${p}" -u "${q}" -b "$BASEDIR" $DODEBUG &
	sudo $MTR --report --show-ips --no-dns --mpls --timeout=$TIMEOUT --report-cycles=$TESTS --interval=$INTERVAL --max-ttl=$MAXHOPS --psize=-$MTU "$p"
done; wait
)

echo
echo -e "amd_pathping script complete"
echo

