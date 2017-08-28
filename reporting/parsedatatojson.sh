#! /bin/bash
# Convert pathping-ng data files to JSON for parsing by D3 
# 

# pathping-ng input data file format
#
##ts source destination hop node sent received lost loss% best average worst stdev geomean jitter avgjitter maxjitter intjitter
#58e1e51d 172.16.51.165 8.8.8.8 1 172.16.51.254 10 10 0 0.000% 2.161 64.606 425.032 129.834 18.375 16.683 87.800 418.338 740.466
#58e1e51d 172.16.51.165 8.8.8.8 2 119.17.37.141 10 10 0 0.000% 10.887 69.642 333.519 97.080 40.265 54.624 69.095 306.557 582.668
#58e1e51d 172.16.51.165 8.8.8.8 3 218.100.52.3 10 10 0 0.000% 14.188 90.775 401.958 117.567 54.781 12.942 79.441 326.149 696.007
#58e1e51d 172.16.51.165 8.8.8.8 4 108.170.247.65 10 10 0 0.000% 9.110 71.229 360.146 104.289 39.847 37.500 84.295 322.278 730.312
#58e1e51d 172.16.51.165 8.8.8.8 5 216.239.40.255 10 10 0 0.000% 7.629 49.499 192.395 54.330 32.348 12.582 46.050 163.116 390.113
#58e1e51d 172.16.51.165 8.8.8.8 6 8.8.8.8 10 10 0 0.000% 8.351 65.260 165.114 57.516 41.913 84.999 50.248 123.880 414.699


# required output format
#
#{
#  "nodes": [
#    {"id": "172.16.51.165", "name": "172.16.51.165", "group": 0, "hopcount": 30},
#    {"id": "172.16.51.254", "name": "172.16.51.254", "group": 1, "hopcount": 30},
#    {"id": "119.17.37.141", "name": "119.17.37.141", "group": 1, "hopcount": 30},
#    {"id": "218.100.52.3", "name": "218.100.52.3", "group": 1, "hopcount": 30},
#    {"id": "108.170.247.81", "name": "108.170.247.81", "group": 1, "hopcount": 20},
#    {"id": "74.125.37.201", "name": "74.125.37.201", "group": 1, "hopcount": 20},
#    {"id": "172.217.25.131", "name": "172.217.25.131", "group": 1, "hopcount": 20},
#    {"id": "2_108.170.247.65", "name": "108.170.247.65", "group": 2, "hopcount": 10},
#    {"id": "2_216.239.40.255", "name": "216.239.40.255", "group": 2, "hopcount": 10},
#    {"id": "2_8.8.8.8", "name": "8.8.8.8", "group": 2, "hopcount": 10}
#  ],
#  "links": [
#    {"source": "172.16.51.165", "target": "172.16.51.254", "value": 1.636, "hopcount": 20},
#    {"source": "172.16.51.254", "target": "119.17.37.141", "value": 7.873, "hopcount": 20},
#    {"source": "119.17.37.141", "target": "218.100.52.3", "value": 8.023, "hopcount": 20},
#    {"source": "218.100.52.3", "target": "108.170.247.81", "value": 7.762, "hopcount": 20},
#    {"source": "108.170.247.81", "target": "74.125.37.201", "value": 10.159, "hopcount": 20},
#    {"source": "74.125.37.201", "target": "172.217.25.131", "value": 9.123, "hopcount": 20},
#    {"source": "172.16.51.165", "target": "172.16.51.254", "value": 2.030, "hopcount": 10},
#    {"source": "172.16.51.254", "target": "119.17.37.141", "value": 7.629, "hopcount": 10},
#    {"source": "119.17.37.141", "target": "218.100.52.3", "value": 7.534, "hopcount": 10},
#    {"source": "218.100.52.3", "target": "2_108.170.247.65", "value": 11.532, "hopcount": 10},
#    {"source": "2_108.170.247.65", "target": "2_216.239.40.255", "value": 8.118, "lost": 10, "hopcount": 10},
#    {"source": "2_216.239.40.255", "target": "2_8.8.8.8", "value": 8.108, "hopcount": 10}
#  ]
#}

# config
DEBUG=0


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



# functions
json_array() {
  echo '['
  while [ $# -gt 0 ]; do
    x=${1//\\/\\\\}
    #echo -n \"${x//\"/\\\"}\"
	echo -n ${x}
    [ $# -gt 1 ] && echo ', '
    shift
  done
  echo -en '\n]'
}

build_node() {
  # group# ipaddress name/ip hopcount
  echo '{"id": "'$2'", "name": "'$3'", "group": '$1', "hopcount": '$4'}'
}

build_link() {
  # group# sourceip targetip latency lostcount hopcount
  if [ $5 -gt 0 ]; then
    echo '{"source": "'$2'", "target": "'$3'", "latency": '$4', "lost": '$5', "hopcount": '$6'}'
  else
    echo '{"source": "'$2'", "target": "'$3'", "latency": '$4', "hopcount": '$6'}'
  fi
}


# main code

# strict error handling
set -euo pipefail

# command line parameters
OPTS=1
while getopts ":hdf:" OPT; do
	case $OPT in
		h)
			OPTS=0  #show help
			;;
		d)
			DEBUG=$((DEBUG + 1))
			;;
		f)
			DATAFILE=$OPTARG
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


#sanity checks

if [ ! -r $DATAFILE ]; then echo "File $DATAFILE not readable!"; exit 1;  fi



# dummy/test code
#echo "testing build_node: "$(build_node 1 "1.1.1.1" "fqdn" 10)
#echo "testing build_link: "$(build_link 1 "1.1.1.1" "1.1.1.2" 1.000 1 20)
#echo "testing build_link: "$(build_link 1 "1.1.1.1" "1.1.1.2" 1.000 0 20)
#
#NODES=("$(build_node 1 "1.1.1.1" "fqdn" 10)" '{"id": "172.16.51.254", "name": "172.16.51.254", "group": 1, "hopcount": 30}' '{"id": "119.17.37.141", "name": "119.17.37.141", "group": 1, "hopcount": 30}')
#LINKS=("$(build_link 2 "2.2.2.2" "3.3.3.3" 1.001 0 10)" '{"source": "172.16.51.165", "target": "172.16.51.254", "value": 1.636, "hopcount": 20}' '{"source": "172.16.51.254", "target": "119.17.37.141", "value": 7.873, "hopcount": 20}')
#
#echo "example json output"
#echo -ne "{\n\"nodes\": "
#json_array "${NODES[@]}"
#echo -ne ",\n\"links\": "
#json_array "${LINKS[@]}"
#echo -ne "\n}\n"
#
#echo "testing done"



# read file
SOURCE=`awk -F" " ' $1 ~ /[0-9a-f]{8}/  { src[$2]++; } END { for (ip in src) { printf("%s,",ip);} }  ' $DATAFILE`
SOURCE=${SOURCE%,}
debugecho "Source: [$SOURCE]"

A_DEST=`awk -F" " ' $1 ~ /[0-9a-f]{8}/  { dst[$3]++; } END { for (ip in dst) { printf("%s,",ip);} }  ' $DATAFILE`
A_DEST=${A_DEST%,}
debugecho "Dests:  [$A_DEST]"

A_NODES=`awk -F" " ' $1 ~ /[0-9a-f]{8}/  { nodes[$5]++; } END { for (ip in nodes) { printf("%s,",ip);} }  ' $DATAFILE`
A_NODES=${A_NODES%,}
debugecho "Nodes:  [$A_NODES]"

declare -a NODES
declare -a LINKS
GROUP=0
prev_hop=""

IFS=,
NODES+=("$(build_node 0 "0_$SOURCE" "$SOURCE" 100)")
for ldst in $A_DEST; do
  debugecho "ldst: [$ldst]"
  if [ "$ldst" == "" ]; then continue; fi
  A_HOPS=`awk -F" " ' $1 ~ /[0-9a-f]{8}/ && $3 == "'$ldst'" { print $0; } ' $DATAFILE`
  debugecho "A_HOPS: [$A_HOPS]"
  
  while IFS=" " read -r ts src dst hopnum hop sent recv lost lossr best avg worst; do

    debugecho "GROUP: [$GROUP] prev_hop: [$prev_hop] hop: [$hop] hopnum: [$hopnum] best: [$best] avg: [$avg]"
    if [ "$hopnum" == "" ]; then continue; fi		# we're done
    if [ $hopnum -eq 1 ]; then GROUP=$((GROUP + 1)); prev_hop="0_$src"; fi
    debugecho "GROUP: [$GROUP] prev_hop: [$prev_hop] hop: [$hop] hopnum: [$hopnum] best: [$best] avg: [$avg]"

	name=$hop
	if [ "$hop" == "$src" ]; then hop="0_$hop"; else hop="${GROUP}_$hop"; fi
    NODES+=("$(build_node $GROUP "$hop" "$name" $sent)")
    debugecho '|${NODES[@]}|' 2

    LINKS+=("$(build_link $GROUP "$prev_hop" "$hop" $avg $lost $sent)")
    debugecho '|${LINKS[@]}|' 2
    prev_hop=$hop

  done < <(echo $A_HOPS)
done

#output final JSON
IFS=""
echo -ne "{\n\"nodes\": "
json_array "${NODES[@]}"
echo -ne ",\n\"links\": "
json_array "${LINKS[@]}"
echo -ne "\n}\n"


