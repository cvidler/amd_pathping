#!/usr/bin/env bash
# amd_pathping Main Script
# Chris Vidler - Dynatrace DCRUM SME 2016
#
# Reads destinations file, and produces data data on network routing and loss.
#

# config 
RTMGATE=/usr/adlex/config/config-access.properties
DSTLIST=/usr/adlex/config/pathpingdests.cfg
CFGFILE=/usr/adlex/config/pathpingconf.cfg
BASEDIR=/var/spool/adlex/rtm
MAXTHREADS=4
DEBUG=0

# defaults global config can override
MAXHOPS=10
TESTS=10
INTERVAL=1.0
TIMEOUT=10
MTU=1500
SOURCEIFC=
PROT=
PORT=





# support functions
function debugecho {
	dbglevel=${2:-1}
	string=${1:-}
	if [ $DEBUG -ge $dbglevel ]; then techo "\e[35m*** DEBUG[$dbglevel]: $string\e[39m "; fi
}

function techo {
	IFS=
	while read line; do
		echo -e "[`date -u`]: ${line:-}"
	done < <(echo -e ${1:-})
}


# Start of script - do not edit below
techo "pathping-ng amd_pathping script"

IFS=$',\n\t'
AWK=`which awk`
GREP=`which grep`
SORT=`which sort`
CAT=`which cat`
JOBS=`which jobs`
WC=`which wc`
XSLTPROC=`which xsltproc`
MTR=`which mtr`
MTR=/home/data_mine/mtr/mtr
if [ $? -ne 0 ]; then echo -e "fatal MTR not found in path/not installed"; exit 1; fi

# strict error handling
set -euo pipefail

# command line parameters
OPTS=1
while getopts ":hdc:l:o:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
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
			techo "\e[31m*** FATAL:\e[39m Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			techo "\e[31m*** FATAL:\e[39m argument -$OPTARG requires parameter."
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
	techo "\e[31m*** FATAL:\e[39m Destinations config list file $DSTLIST not found. Aborting."
	exit 1
fi

if [ ! -r "$CFGFILE" ]
then 
	techo "\e[31m*** FATAL:\e[39m Global config list file $CFGFILE not found. Aborting."
	exit 1
fi

if [ ! -r "$RTMGATE" ]
then 
	techo "\e[33m*** WARNING:\e[39m RTMGATE config access file $RTMGATE not found/readable."
else
	techo "Check rtmgate access permissions: "
	TESTRESULT=`$GREP "pathping\*.cfg" "$RTMGATE"`
	if [ "$TESTRESULT" == "" ] 
	then
		techo "rtmgate config not found, adding..."

		# each line in the file is uniquely numbered, find the last one, and add one
		LASTNUM=`$AWK -F"[.=]" '/ConfigFile/{a=$2}; END {print a};' "$RTMGATE"`
		#echo "[$LASTNUM]"
		NEWNUM=$((LASTNUM + 1))
		#echo "[$NEWNUM]"
		# check for write permissions
		if [ ! -w "$RTMGATE" ] 
		then
			techo "\n\e[31m*** FATAL:\e[39m rtmgate config $RTMGATE not writeable. Aborting."
			exit 1
		fi
		# add new entry to rtmgate config
		echo -e "ConfigFile.$NEWNUM=pathping*.cfg\n" >> $RTMGATE
		# restart rtmgate (safe, no outage to monitoring)
		techo "Restarting RTMGATE daemon to enable change"
		`systemctl restart rtmgate`
	else
		techo "OK"
	fi
fi

if [ ! -w "$BASEDIR" ]
then
	techo "\e[31m*** FATAL:\e[39m Output storage directory $BASEDIR not found or not writeable. Aborting."
	exit 1
fi


# Lets start things
techo "Loading global configuration from config file: $CFGFILE"

#read global config file
IFS="=";
while read a v; do
	#echo -e "$a:$v"
	case "${a,,}" in
		timeout)
			TIMEOUT=$v
			;;
		interval | int)
			INTERVAL=$v
			;;
		maxhops)
			MAXHOPS=$v
			;;
		count)
			TESTS=$v
			;;
		maxmtu | mtu)
			MTU=$v
			;;
		protocol | prot)
			PROT=$v
			;;
		port)
			PORT=$v
			;;
		source | src)
			SOURCEIFC=$v
			;;
		\#*|'')
			#comment/blank lines
			;;
		*)
			techo "\e[33m*** WARNING:\e[39m Ignoring unknown config line: $a"
			;;
	esac
done < $CFGFILE
IFS=$',\n\t'

# mtr needs root for intervals below 1 second, check the config and if root or not.
#echo "[$INTERVAL]"
SUDOCMD=""
if [[ $INTERVAL =~ 0\.[0-9]+ ]]; then
	if [ $EUID -ne 0 ]; then
		techo "\e[31m*** FATAL:\e[39m <1.0 sec Interval requires root."
		exit 1
	fi
	SUDOCMD="`which sudo` "
else
	SUDOCMD=""
fi

if [ ! $PROT == "" ] && [ $PORT == "" ]; then
	#protocol specified but no port, bail out
	techo "\e[31m*** FATAL:\e[39m Protocol specified, but not port specified. Aborting."
	exit 1
fi


#display global configs
techo "  Source IFC: ${SOURCEIFC:-default route}"
techo "  Timeout:    ${TIMEOUT}"
techo "  Interval:   ${INTERVAL}"
techo "  Max Hops:   ${MAXHOPS}"
techo "  Tests:      ${TESTS}"
techo "  Max MTU:    ${MTU}"
techo "  Protocol:   ${PROT:-icmp}"
techo "  Port:       ${PORT:-n/a}"
techo 


#display destinations from config file
techo "Loading destinations to test from config file: $DSTLIST"
techo
techo "`$AWK -F"," '$1 ~ /^[Aa]/ { print "+" $2 "" } ' $DSTLIST`"
techo "`$AWK -F"," '$1 ~ /^[Dd]/ { print "-" $2 " Disabled" } ' $DSTLIST`"
techo

# generate hourly data files
TIMESTAMP=`date -d "\`date -u +"%Y-%m-%d %H:00:00"\`" +%s` ; TIMESTAMP=`printf "%x" $TIMESTAMP`
debugecho "TIMESTAMP=$TIMESTAMP"
OUTFILE="$BASEDIR/pathping_${TIMESTAMP}_e10_t"
debugecho "OUTFILE=$OUTFILE"

# determine active interface
SRC=`ip addr | grep "state UP" -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'` 
debugecho "SRC=$SRC"

#output header data to file if not already existing
if [ ! -r $OUTFILE ]; then echo "#ts source destination hop node sent received lost loss% best average worst stdev geomean jitter avgjitter maxjitter intjitter" > $OUTFILE; fi

# build source address command line if present
if [ ! "$SOURCEIFC" == "" ]; then
	SOURCEIFC="--address $SOURCEIFC"
fi

# build protocol/port command line
if [ '${PROT,,}' == 'tcp' ]; then PROT="--tcp --port $PORT"; fi
if [ '${PROT,,}' == 'udp' ]; then PROT="--udp --port $PORT"; fi

#iterate through active destinations testing them.
$AWK -F"," '$1 ~ /^[Aa]/ { print $2 } ' $DSTLIST | ( while read p; do 

	#pause while thread count high
	while [ $($JOBS -r | $WC -l) -ge $MAXTHREADS ]; do sleep 1; done

	#start test (as a background subshell)
	(
	techo "Performing testing for destination: ${p}"
	TMPFILE=`mktemp -t pathpingng.XXXXXXXX`
	debugecho "PID=$BASHPID DEST=$p TMPFILE=$TMPFILE"
	TS=`date -u +%s`; TS=`printf "%x" $TS`
	
	$MTR --no-dns --timeout=$TIMEOUT --report-cycles=$TESTS --interval=$INTERVAL --max-ttl=$MAXHOPS --psize=-$MTU $SOURCEIFC --xml ${p} > $TMPFILE
	if [ $? -ne 0 ]; then techo "*** WARNING: Couldn't run mtr test for destination: ${p}"; fi
	$XSLTPROC --novalid mtrxml.xslt "$TMPFILE" | $AWK -F" " -v ts="$TS" -v src="$SRC" '{ print ts,src,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17 }' >> $OUTFILE
	if [ $? -ne 0 ]; then techo "*** WARNING: Couldn't parse XML output from mtr for destination: ${p}"; fi
	debugecho "`$CAT $TMPFILE`" 2
	rm $TMPFILE
	) &

done; wait
)

#complete
techo
techo "pathping-ng amd_pathping script complete"
techo
debugecho "Output follows:" 2; debugecho "`cat $OUTFILE`" 2



