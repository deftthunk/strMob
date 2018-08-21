#!/bin/bash

threads=4

process () {
	f=$1
	n=$2
	grep -P "[0-9A-Za-z]{$n}" .tmpFile4 >> .out.$f
	rm .tmpFile*
}

parse () {
	f=$1
	fname=`basename $1`

	strings -a -es -n5 --radix=d $f > .strings_es_$fname & \
	strings -a -eS -n5 --radix=d $f > .strings_eS_$fname & \
	strings -a -el -n5 --radix=d $f > .strings_el_$fname & \
	strings -a -eL -n5 --radix=d $f > .strings_eL_$fname & \
	strings -a -eb -n5 --radix=d $f > .strings_eb_$fname & \
	strings -a -eB -n5 --radix=d $f > .strings_eB_$fname & \
	strings -a -es -n5 --radix=d $f > .strings_es_$fname & 

	while [[ `ps -C strings --no-header` ]]; do
		sleep 1
	done
}

sorting () {
	sort -k2 --ignore-nonprinting --parallel=$threads -o .tmpFile1 .strings_$1
	uniq -f1 -i .tmpFile1 .tmpFile2
	sort -k1 -n --parallel=$threads -o .tmpFile3 .tmpFile2
	awk '{print $2}' .tmpFile3 > .tmpFile4
}

for file in $@; do
	path=$file
	name=`basename $file`
	parse $path $name
	cat .strings_* > .strings_$name

	sorting $name
	
	# target different human-readable string lengths
	for num in {5..10}; do
		process $name $num
	done
	# clean up previous run
	rm .strings_*
	mv .out.$name .strings_$name
	
	# last pass
	sorting $name 
	process $name 1
	mv .out.$name strings.$name
	rm .out*
done

