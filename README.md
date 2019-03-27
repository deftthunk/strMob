# strmob
Wrapper around the 'strings' command to help quickly process all available 
string encodings, with a focus on speeding up processing large files.

### Features:
- attempts all encoding variations found in the 'strings' command
- processes large files quickly
- removes duplicate entries
- removes excess whitespace
- displays file offset for each string
- prints a progress ruler for tracking location in large files

### Usage:
  > ~$ strmob FILE1 [FILE2]..."
  > ~$ strmob -q FILE1 [FILE2]..."
  '-q' == quiet (do not print anything other than strings)"

