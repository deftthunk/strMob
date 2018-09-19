#!/bin/bash

threads=4

parse () {
	f=$1
	fname=`basename $1`

	strings -a -es -n5 --radix=d $f > .strings_es_$fname & \
	strings -a -eS -n5 --radix=d $f > .strings_eS_$fname & \
	strings -a -el -n5 --radix=d $f > .strings_el_$fname & \
	strings -a -eL -n5 --radix=d $f > .strings_eL_$fname & \
	strings -a -eb -n5 --radix=d $f > .strings_eb_$fname & \
	strings -a -eB -n5 --radix=d $f > .strings_eB_$fname &

	while [[ `ps -C strings --no-header` ]]; do
		sleep 1
	done
}

process () {
	for num in {5..10}; do
		grep -P --binary-files=text "^\s*?\d+\s.*?[0-9A-Za-z]{$num}" .strall >> .out.$name
	done

	# replace non-ascii chars with whitespace
	perl -i -pe 's/[^[:ascii:]]/ /g' .out.$name
	sed -i 's/\s\s+/\s/g' .out.$name
}

sorting () {
	sort -k2 --ignore-nonprinting --parallel=$threads -o .tmpFile1 .out.$name
	uniq -f1 -i .tmpFile1 .tmpFile2
	sort -k1 -n --parallel=$threads -o .tmpFile3 .tmpFile2

	# print all but first column, removing file indexing but preserving order
	awk '{$1=""; print $0}' .tmpFile3 > final
}

for file in $@; do
	path=$file
	name=`basename $file`
	parse $path $name
	cat .strings_* > .strall

	process
	sorting

	# clean up
	rm .tmpFile* .strings_* .out.$name .strall
	
done

