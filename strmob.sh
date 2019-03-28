#!/bin/bash

# $Ss: strmob :sS$ 
# wrapper around the 'strings' command to help quickly process all available 
# string encodings. 
# 
# Features:
# - attempts all encoding variations found in the 'strings' command
# - processes large files quickly
# - removes duplicate entries
# - removes excess whitespace
# - displays file offset for each string
# - prints a progress ruler for tracking location in large files
#
# Usage:
#		> ~$ strmob FILE1 [FILE2]..."
#		> ~$ strmob -q FILE1 [FILE2]..."
#		'-q' == quiet (do not print anything other than strings)"
#
#
#
# <CONFIG VARS>
# threads   -> how many CPU threads to use for sorting. useful for large files
# minStrLen -> minimum string length to qualify for displaying
threads=8
minStrLen=4


printStatus () {
	quiet=$2
	if [[ $quiet -eq 0 ]]; then
		echo "$1"
	fi
}


parse () {
	quiet=$1
	parent="$2"
	f="$3"
	fname="`basename "$3"`"
	printStatus '> Finding 7/16/32-bit (big/little)endian' $quiet

	strings -a -es -n $minStrLen --radix=d "$f" > "$parent"/.strings_es_"$fname" & \
	strings -a -eS -n $minStrLen --radix=d "$f" > "$parent"/.strings_eS_"$fname" & \
	strings -a -el -n $minStrLen --radix=d "$f" > "$parent"/.strings_el_"$fname" & \
	strings -a -eL -n $minStrLen --radix=d "$f" > "$parent"/.strings_eL_"$fname" & \
	strings -a -eb -n $minStrLen --radix=d "$f" > "$parent"/.strings_eb_"$fname" & \
	strings -a -eB -n $minStrLen --radix=d "$f" > "$parent"/.strings_eB_"$fname" &

	while [[ `ps -C strings --no-header` ]]; do
		sleep 1
	done
}


process () {
	quiet=$1
	parent="$2"
	printStatus '> Prune unlikely candidates' $quiet
	grep -P --binary-files=text "^\s*?\d+\s.*?[0-9A-Za-z]{$minStrLen}" "$parent"/.strall > "$parent"/.out."$name"

	printStatus '> Replace non-ascii chars with whitespace' $quiet
	perl -i -pe 's/[^[:ascii:]]/\s/g' "$parent"/.out."$name"

	printStatus '>    --Pass 1/3' $quiet
	sed -i 's/\s\s+/\s/g' "$parent"/.out."$name"

	printStatus '>    --Pass 2/3' $quiet
	sed -i 's/^\s//g' "$parent"/.out."$name"

	printStatus '>    --Pass 3/3' $quiet
	sed -i 's/\s$//g' "$parent"/.out."$name"
}


sorting () {
	quiet=$1
	parent="$2"
	printStatus '> Sort and uniq' $quiet
	sort -k2 --ignore-nonprinting --parallel=$threads -o "$parent"/.tmpFile1 "$parent"/.out."$name"
	uniq -f1 -i "$parent"/.tmpFile1 "$parent"/.tmpFile2

	printStatus '> Rearrange strings to original ordering' $quiet
	sort -k1 -n --parallel=$threads -o "$parent"/.tmpFile3 "$parent"/.tmpFile2

	# determine if user wants to print out rulers or just strings
	if [[ $quiet -eq 1 ]]; then
		# print all but first column, removing file indexing but preserving order
		awk '{$1=""; print $0}' "$parent"/.tmpFile3 | sed 's/^\s*//g' > "$parent"/.final
		cp "$parent"/.final "$parent"/strings."$name"
	else
		cp "${parent}/.tmpFile3" "${parent}/.final"
		printStatus '> Adding offset and progress ruler' $quiet

		`perl -e '$l=0; open(FH, "'"$parent"/.final'");' \
			-e '$l++ while(<FH>); seek FH,0,0;' \
			-e '$chunk = ($l / 100);' \
			-e '$ln=0; $p=1; foreach(<FH>) {' \
			-e '/^\s*?(\d+)\s+(.*)$/; $offset=$1; $string=$2;' \
			-e '$hex = sprintf("0x%X", $offset);' \
			-e 'printf("%s\%\t%-8s:  %-s\n", $p, $hex, $string); $ln++;' \
			-e 'if($ln > ($chunk * $p)) {$p++;} close(FH);' \
			-e '}' > "$parent"/strings."$name"`
	fi
}


main () {
	quiet=0

	if [[ $# -eq 0 ]]; then
		echo "> ~$ strmob FILE1 [FILE2]..."
		echo "> ~$ strmob -q FILE1 [FILE2]..."
		echo "> '-q' == quiet (do not print anything other than strings)"
	fi

	for file in "$@"; do
		if [[ "$file" == '-q' ]]; then
			quiet=1
			continue
		fi

		path="$file"
		name="`basename "$file"`"
		parent="`dirname "$file"`"

		if [[ "$parent" == '.' ]]; then
			parent="$PWD"
		fi

		parse $quiet "$parent" "$path"

		# roundabout way to handle paths/names with spaces, since bash often has
		# problems handling this in scripts
		exec 9< <( find "$parent" -type f -name '.strings_*' -print0 )
		while IFS= read -r -d '' -u 9; do
			strTempFile="$(readlink -fn -- "$REPLY"; echo x)"
			strTempFile="${strTempFile%x}"
			cat "$strTempFile" >> "$parent"/.strall
		done

		process $quiet "$parent"
		sorting $quiet "$parent"

		printStatus '> Cleaning up' $quiet
		exec 9< <( find "$parent" -type f \( -name ".strings_*" -o -name '.tmpFile*' \) -print0 )
		while IFS= read -r -d '' -u 9; do
			delFile="$(readlink -fn -- "$REPLY"; echo x)"
			delFile="${delFile%x}"
			rm "$delFile"
		done
		rm "$parent"/.strall "$parent"/.final "$parent"/.out."$name"
	
	done
}


main "$@"
