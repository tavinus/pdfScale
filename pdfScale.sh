#!/usr/bin/env bash

# pdfScale.sh
#
# Scale PDF to specified percentage of original size.
#
# Gutavo Arnosti Neves - 2016 / 07 / 10
#
# This script: https://github.com/tavinus/pdfScale
#    Based on: http://ma.juii.net/blog/scale-page-content-of-pdf-files
#         And: https://gist.github.com/MichaelJCole/86e4968dbfc13256228a


VERSION="1.0.5"
SCALE=0.95   # scaling factor (0.95 = 95%, e.g.)
VERBOSE=0    # verbosity Level


printVersion() {
	echo "$(basename $0) v$VERSION"
}

printHelp() {
	printVersion
	echo "
Usage: $0 [-v] [-s <factor>] <inFile.pdf> [outfile.pdf]
       $0 -h
       $0 -V

Parameters:
 -v          Verbose mode, prints extra information
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
 -s <factor> Changes the scaling factor, defaults to 0.95
             MUST be a number bigger than zero. 
             Eg. -s 0.8 for 80% of the original size 

Notes:
 - Options must be passed before the file names to be parsed
 - The output filename is optional. If no file name is passed
   the output file will have the same name/destination of the
   input file, with .SCALED.pdf at the end (instead of just .pdf)
 - Having the extension .pdf on the output file name is optional,
   it will be added if not present
 - Should handle file names with spaces without problems
 - The scaling is centered and using a scale bigger than 1 may
   result on cropping parts of the pdf.

Examples:
 pdfScale myPdfFile.pdf
 pdfScale myPdfFile.pdf myScaledPdf
 pdfScale -v myPdfFile.pdf
 pdfScale -s 0.85 myPdfFile.pdf myScaledPdf.pdf
 pdfScale -v -s 0.7 myPdfFile.pdf
 pdfScale -h
"
}

usage() { 
	printVersion
	echo "Usage: $0 [-v] [-s <factor>] <inFile.pdf> [outfile.pdf]" 1>&2
	echo "Try:   $0 -h # for help" 1>&2
	exit 1
}

parseScale() {
	if ! [[ -n "$1" && "$1" =~ ^-?[0-9]*([.][0-9]+)?$ && (($1 > 0 )) ]] ; then
		echo "Invalid factor: $1"
		echo "The factor must be a number between 0 and 1."
		echo "Example: for 80% use 0.8"
		exit 2
	fi
	SCALE=$1
}

vprint() {
	[[ $VERBOSE -eq 0 ]] && return 0
	timestamp="$(date +%Y-%m-%d:%H:%M:%S)"
	echo "$timestamp | $1"
}

while getopts ":vhVs:" o; do
    case "${o}" in
        v)
            VERBOSE=1
            ;;
        h)
            printHelp
            exit 0
            ;;
        V)
            printVersion
            exit 0
            ;;
        s)
            parseScale ${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

printDependency() {
	echo >&2 $'\n'"ERROR! You need to install the package '$1'"$'\n'
	echo >&2 "Linux apt-get.: sudo apt-get install $1"
	echo >&2 "Linux yum.....: sudo yum install $1"
	echo >&2 "MacOS homebrew: brew install $1"
	echo >&2 $'\n'"Aborting..."
	exit 3
}

vprint "$(basename $0) v$VERSION - Verbose execution"

# Dependencies
vprint "Checking dependencies"
command -v identify >/dev/null 2>&1 || printDependency 'imagemagick'
command -v gs >/dev/null 2>&1 || printDependency 'ghostscript'
command -v bc >/dev/null 2>&1 || printDependency 'bc'

vprint "  Scale factor: $SCALE"

# Validate args.
[[ $# -lt 1 ]] && { usage; exit 1; }
INFILEPDF="$1"
[[ "$INFILEPDF" =~ ^..*\.pdf$ ]] || { usage; exit 2; }
vprint "    Input file: $INFILEPDF"

if [[ -z $2 ]]; then
	OUTFILEPDF="${INFILEPDF%.pdf}.SCALED.pdf"
else
	OUTFILEPDF="${2%.pdf}.pdf"
fi
vprint "   Output file: $OUTFILEPDF"


# Get width/height in postscript points (1/72-inch), via ImageMagick identify command.
# (Alternatively, could use Poppler pdfinfo command; or grep/sed the PDF by hand.)
IDENTIFY=$(identify -format "%G" "$INFILEPDF" 2>/dev/null)
[[ -z $IDENTIFY ]] && { echo "Error when getting PDF size! Aborting..." ; exit 11; }

IDENTIFY="$(echo "$IDENTIFY" | tr "x" " " 2>/dev/null | tr -d "+" 2>/dev/null)"
IDENTIFY=($(echo "$IDENTIFY")) # transform in a bash array
PGWIDTH=${IDENTIFY[0]}
PGHEIGHT=${IDENTIFY[1]}
vprint "         Width: $PGWIDTH postscript-points"
vprint "        Height: $PGHEIGHT postscript-points"


# Compute translation factors (to center page.
XTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGWIDTH" | bc)
YTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGHEIGHT" | bc)
vprint " Translation X: $XTRANS"
vprint " Translation Y: $YTRANS"

#echo $PGWIDTH , $PGHEIGHT , $OUTFILEPDF , $SCALE , $XTRANS , $YTRANS , $INFILEPDF , $OUTFILEPDF

# Do it.
gs \
-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dSAFER \
-dCompatibilityLevel="1.5" -dPDFSETTINGS="/printer" \
-dColorConversionStrategy=/LeaveColorUnchanged \
-dSubsetFonts=true -dEmbedAllFonts=true \
-dDEVICEWIDTH=$PGWIDTH -dDEVICEHEIGHT=$PGHEIGHT \
-sOutputFile="$OUTFILEPDF" \
-c "<</BeginPage{$SCALE $SCALE scale $XTRANS $YTRANS translate}>> setpagedevice" \
-f "$INFILEPDF"
