cat pathping_5782a940_e10_t | awk -F" " ' $1 ~ /[0-9a-f]{8}/  { src=$2; dst=$3; hop=$4; host=$5; lost=$6; avg=$9; printf("src_%s ",src); printf("dst_%s ",dst); printf("%s ",hop); printf("hop_%s_%s_%s\%_%sms\n",hop,host,lost,avg) }  ' > parsedsplit.txt


cat parsedsplit.txt | awk -F" " ' BEGIN { print "<graphml>\n<graph edgedefault=\"directed\">"  } $1 ~ /src_.*/ { printf("<node id=\"%s\"/>",$1); print "" } $4 ~ /hop_[0-9]+_.*/ { if ( $3 == "1" ) { prevhop=$1 }} { printf("<node id=\"%s\"/>",$4) ; printf("<edge source=\"%s\" target=\"%s\"/>\n",prevhop,$4); prevhop=$4 } END { print "</graph>\n</graphml>" }' | awk '!seen[$0] {print} {seen[$0]++}' > test.gml


