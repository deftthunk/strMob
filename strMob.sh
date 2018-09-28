#!/bin/bash

threads=4
minLen=5

parse () {
	f=$1
	fname=`basename $1`
	echo "> Finding 7/16/32-bit (big/little)endian"

	strings -a -es -n $minLen --radix=d $f > .strings_es_$fname & \
	strings -a -eS -n $minLen --radix=d $f > .strings_eS_$fname & \
	strings -a -el -n $minLen --radix=d $f > .strings_el_$fname & \
	strings -a -eL -n $minLen --radix=d $f > .strings_eL_$fname & \
	strings -a -eb -n $minLen --radix=d $f > .strings_eb_$fname & \
	strings -a -eB -n $minLen --radix=d $f > .strings_eB_$fname &

	while [[ `ps -C strings --no-header` ]]; do
		sleep 1
	done
}

process () {
	echo "> Prune unlikely candidates"
	grep -P --binary-files=text "^\s*?\d+\s.*?[0-9A-Za-z]{$minLen}" .strall > .out.$name

	echo "> Replace non-ascii chars with whitespace"
	perl -i -pe 's/[^[:ascii:]]/\s/g' .out.$name

	echo ">    --Pass 1/3"
	sed -i 's/\s\s+/\s/g' .out.$name

	echo ">    --Pass 2/3"
	sed -i 's/^\s//g' .out.$name

	echo ">    --Pass 3/3"
	sed -i 's/\s$//g' .out.$name
}

sorting () {
	echo "> Sort and uniq"
	sort -k2 --ignore-nonprinting --parallel=$threads -o .tmpFile1 .out.$name
	uniq -f1 -i .tmpFile1 .tmpFile2

	echo "> Rearrange strings to original ordering"
	sort -k1 -n --parallel=$threads -o .tmpFile3 .tmpFile2

	# print all but first column, removing file indexing but preserving order
	awk '{$1=""; print $0}' .tmpFile3 > .final

	echo "> Adding index and progress ruler"
	`cat .final | perl -ne '$l=0; open(FH, ".final");' \
		-e '$l++ while(<FH>); close(FH);' \
		-e '$chunk = ($l / 100);' \
		-e '$ln=0; $p=1; foreach(<>) {' \
		-e 'print("$ln-$p%:\t$_"); $ln++;' \
		-e 'if($ln > ($chunk * $p)) {$p++;}' \
		-e '}' > strings.$name`
}

for file in $@; do
	path=$file
	name=`basename $file`
	parse $path $name
	cat .strings_* > .strall

	process
	sorting

	echo "> Cleanup"
	rm .tmpFile* .strings_* .out.$name .strall .final
	
done
