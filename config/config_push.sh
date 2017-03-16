#!/usr/bin/env bash
# config_push Script
# Chris Vidler - Dynatrace DCRUM SME 2016
#
# Publishes pathping_ng config (global config and destination list) to AMDs using AMD list.
#



# Configuration
AMDLIST=/etc/amdlist.cfg
DSTLIST=/etc/pathping/pathpingdests.cfg
CFGFILE=/etc/pathping/pathpingconf.cfg
PIDFILE=/tmp/pathping-publish.pid
MAXTHREADS=4


# Script follows, do not edit.

JOBS=`which jobs`
WC=`which wc`
AWK=`which awk`
CURL=`which curl`


function debugecho {
	dbglevel=${2:-1}
	if [ $DEBUG -ge $dbglevel ]; then techo "*** DEBUG[$dbglevel]: $1"; fi
}

function techo {
	echo -e "[`date -u`]: $1" 
}

tstart=`date -u +%s`
techo "pathping-ng configuration publish script"


# command line parameters
OPTS=1
while getopts ":hda:g:l:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
			;;
		a)
			AMDLIST=$OPTARG
			;;
		g)
			CFGFILE=$OPTARG
			;;
		l)
			DSTLIST=$OPTARG
			;;
		\?)
			OPTS=0 #show help
			techo "*** FATAL: Invalid argument -$OPTARG."
			;;
		:)
			OPTS=0 #show help
			techo "*** FATAL: argument -$OPTARG requires parameter."
			;;
	esac
done

if [ $OPTS -eq 0 ]; then
	echo -e "*** INFO: Usage: $0 [-h] [-a amdlist] [-g globalconfigfile] [-l destlistfile]"
	echo -e "-h This help"
	echo -e "-a Full path to amdlist file, default $AMDLIST"
	echo -e "-g Full path to globalconfigfile, default $CFGFILE"
	echo -e "-l Full path to destlistfile, default $DSTLIST"
	exit 0
fi


# Some sanity checking of the config parameters above
if [ ! -r "$AMDLIST" ]
then 
	techo "\e[31m***FATAL:\e[39m AMD config list file $AMDLIST not found. Aborting."
	exit 1
fi

if [ ! -r "$DSTLIST" ]
then
	techo "\e[31m***FATAL:\e[39m Destination list file $DSTLIST not found or not readable. Aborting."
	exit 1
fi

if [ ! -r "$CFGFILE" ]
then
	techo "\e[31m***FATAL:\e[39m Global configuration file $CFGFILE not found or not readable. Aborting."
	exit 1
fi

if [ ! -r $PIDFILE ]; then
	echo -e "$$" > $PIDFILE
else
	techo "pathping config publish script already running pid: `cat $PIDFILE`. Aborting."
	exit 1
fi

# start publishing
techo "Loading AMDs from config file: $AMDLIST"
AAMDLIST="`$AWK -F"," '$1=="A" { print " + " $3 "" } ' $AMDLIST`"
DAMDLIST="\e[2m`$AWK -F"," '$1=="D" { print " - " $3 " Disabled" } ' $AMDLIST`\e[0m"
techo "$AAMDLIST"
techo "$DAMDLIST"


DODEBUG=""
amds=0
AAMDS=`$AWK -F"," '$1=="A" { print $3","$2 } ' $AMDLIST`
debugecho "AAMDS: [$AAMDS]" 2
while IFS=$',' read -r p q; do
	debugecho "p: [$p] q: [$q]" 2
	while [ $($JOBS -r | $WC -l) -ge $MAXTHREADS ]; do sleep 1; done
	amds=$((amds+1))
	(
		techo "Publishing config files to AMD: ${p}"
		#if [ $DEBUG -ne 0 ]; then DODEBUG=-`$HEAD -c $DEBUG < /dev/zero | $TR '\0' 'd' `; fi
		#RUNCMD="$SCRIPTDIR/collectamd.sh -n \"${p}\" -u \"${q}\" -b \"$BASEDIR\" $DODEBUG &"
		#debugecho "RUNCMD: $RUNCMD"
		#$SCRIPTDIR/collectamd.sh -n "${p}" -u "${q}" -b "$BASEDIR" $DODEBUG &

		# start a config update transaction
		TRANS=`$CURL --insecure --silent --retry 3 --basic "$q/RtmConfigServlet?cfg_oper=start_trans&cfg_trans_life=300000"`
		echo "TRANS[$TRANS]"

		# send global config
		GC_FILE=`mktemp -t pathpingng.XXXXXXXX`
		cp "$CFGFILE" "$GC_FILE"
		GC_NAME=$(basename "$CFGFILE")
		GC_RESP=`$CURL --insecure --silent --retry 3 --basic --data-urlencode "cfg_data@$GC_FILE" "$q/RtmConfigServlet?cfg_trans=$TRANS&cfg_oper=put_cfg_file&cfg_file=$GC_NAME&cfg_tstamp=0"`
		echo "GC_RESP[$GC_RESP]"
		rm -f "$GC_FILE"

		# send destinations list
		DL_FILE=`mktemp -t pathpingng.XXXXXXXX`
		#gzip -c "$DSTLIST" > "$DL_FILE"
		cp "$DSTLIST" "$DL_FILE"
		DL_NAME=$(basename "$DSTLIST")
		DL_RESP=`$CURL --insecure --silent --retry 3 --basic --data-urlencode "cfg_data@$DL_FILE" "$q/RtmConfigServlet?cfg_trans=$TRANS&cfg_oper=put_cfg_file&cfg_file=$DL_NAME&cfg_tstamp=0"`
		echo "DL_RESP[$DL_RESP]"
		rm -f "$DL_FILE"

		# close transaction
		CLOSE_TRANS=`$CURL --insecure --silent --retry 3 --basic "$q/RtmConfigServlet?cfg_oper=commit_trans&cfg_trans=$TRANS"`
		echo "CLOSE_TRANS[$CLOSE_TRANS]"		

		wait;
	)
done < <(echo "$AAMDS")

rm -f $PIDFILE

tfinish=`date -u +%s`
tdur=$((tfinish-tstart))
techo "pathping-ng collection script completed $amds AMDs in $tdur seconds"



