#!/usr/bin/env bash

# pdfScale.sh
#
# Scale PDF to specified percentage of original size.
#
# Gustavo Arnosti Neves - 2016 / 07 / 10
#
# This script: https://github.com/tavinus/pdfScale
#    Based on: http://ma.juii.net/blog/scale-page-content-of-pdf-files
#         And: https://gist.github.com/MichaelJCole/86e4968dbfc13256228a


VERSION="1.2.10"
SCALE="0.95"               # scaling factor (0.95 = 95%, e.g.)
VERBOSE=0                  # verbosity Level
BASENAME="$(basename $0)"  # simplified name of this script
GSBIN=""                   # Set with which after we check dependencies
BCBIN=""                   # Set with which after we check dependencies
IDBIN=""                   # Set with which after we check dependencies

LC_MEASUREMENT="C"         # To make sure our numbers have .decimals
LC_ALL="C"                 # Some languages use , as decimal token
LC_CTYPE="C"
LC_NUMERIC="C"

TRUE=0                     # Silly stuff
FALSE=1

USEIMGMGK=$FALSE           # ImageMagick Flag, will use identify if true


# Prints version
printVersion() {
        if [[ $1 -eq 2 ]]; then
                echo >&2 "$BASENAME v$VERSION"
        else
                echo "$BASENAME v$VERSION"
        fi
}


# Prints help info
printHelp() {
        printVersion
        echo "
Usage: $BASENAME [-v] [-s <factor>] [-i] <inFile.pdf> [outfile.pdf]
       $BASENAME -h
       $BASENAME -V

Parameters:
 -v          Verbose mode, prints extra information
             Use twice for even more information
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
 -i          Use imagemagick to get page size, 
             instead of cat + grep method
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
 $BASENAME myPdfFile.pdf
 $BASENAME myPdfFile.pdf myScaledPdf
 $BASENAME -v -v myPdfFile.pdf
 $BASENAME -s 0.85 myPdfFile.pdf myScaledPdf.pdf
 $BASENAME -i -s 0.80 -v myPdfFile.pdf
 $BASENAME -v -v -s 0.7 myPdfFile.pdf
 $BASENAME -h
"
}


# Prints usage info
usage() { 
        printVersion 2
        echo >&2 "Usage: $BASENAME [-v] [-s <factor>] <inFile.pdf> [outfile.pdf]"
        echo >&2 "Try:   $BASENAME -h # for help"
        exit 1
}


# Prints Verbose information
vprint() {
        [[ $VERBOSE -eq 0 ]] && return 0
        timestamp=""
        [[ $VERBOSE -gt 1 ]] && timestamp="$(date +%Y-%m-%d:%H:%M:%S) | "
        echo "$timestamp$1"
}


# Prints dependency information and aborts execution
printDependency() {
        printVersion 2
        echo >&2 $'\n'"ERROR! You need to install the package '$1'"$'\n'
        echo >&2 "Linux apt-get.: sudo apt-get install $1"
        echo >&2 "Linux yum.....: sudo yum install $1"
        echo >&2 "MacOS homebrew: brew install $1"
        echo >&2 $'\n'"Aborting..."
        exit 3
}


# Parses and validates the scaling factor
parseScale() {
        if ! [[ -n "$1" && "$1" =~ ^-?[0-9]*([.][0-9]+)?$ && (($1 > 0 )) ]] ; then
                echo >&2 "Invalid factor: $1"
                echo >&2 "The factor must be a floating point number greater than 0"
                echo >&2 "Example: for 80% use 0.8"
                exit 2
        fi
        SCALE=$1
}


# Gets page size using imagemagick's identify
getPageSizeImagemagick() {
	# get data from image magick
        local identify="$("$IDBIN" -format '%[fx:w] %[fx:h]BREAKME' "$INFILEPDF" 2>/dev/null)"

	identify="${identify%%BREAKME*}"   # get page size only for 1st page
	identify=($identify)               # make it an array
	PGWIDTH=${identify[0]}             # assign
        PGHEIGHT=${identify[1]}
}


# Gets page size using cat and grep
getPageSize() {
        # get MediaBox info from PDF file using cat and grep, these are all possible
        # /MediaBox [0 0 595 841]
        # /MediaBox [ 0 0 595.28 841.89]
        # /MediaBox[ 0 0 595.28 841.89 ]

        # Get MediaBox data if possible
        local mediaBox="$(cat "$INFILEPDF" | grep -a '/MediaBox' | head -n1)"
        mediaBox="${mediaBox##*/MediaBox}"

        # If no MediaBox, try BBox
        if [[ -z $mediaBox ]]; then
                mediaBox="$(cat "$INFILEPDF" | grep -a '/BBox' | head -n1)"
                mediaBox="${mediaBox##*/BBox}"
        fi

        # No page size data available
        if [[ -z $mediaBox ]]; then
                echo "Error when reading input file!"
                echo "Could not determine the page size!"
                echo "There is no MediaBox or BBox in the pdf document!"
                echo "Aborting..."
                exit 15
        fi

        # remove chars [ and ]
        mediaBox="${mediaBox//[}"
        mediaBox="${mediaBox//]}"

        mediaBox=($mediaBox)        # make it an array
        mbCount=${#mediaBox[@]}     # array size

        # sanity
        if [[ $mbCount -lt 4 ]]; then 
            echo "Error when reading the page size!"
            echo "The page size information is invalid!"
            exit 16
        fi

        # we are done
        PGWIDTH=$(printf '%.0f' "${mediaBox[2]}")  # Get Round Width
        PGHEIGHT=$(printf '%.0f' "${mediaBox[3]}") # Get Round Height
}


# Parse options
while getopts ":vihVs:" o; do
    case "${o}" in
        v)
            ((VERBOSE++))
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
        i)
            USEIMGMGK=$TRUE
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))



######### START EXECUTION

#Intro message
vprint "$(basename $0) v$VERSION - Verbose execution"


# Dependencies
vprint "Checking for ghostscript and bcmath"
command -v gs >/dev/null 2>&1 || printDependency 'ghostscript'
command -v bc >/dev/null 2>&1 || printDependency 'bc'
if [[ $USEIMGMGK -eq $TRUE ]]; then
        vprint "Checking for imagemagick's identify"
        command -v identify >/dev/null 2>&1 || printDependency 'imagemagick'
        IDBIN=$(which identify 2>/dev/null)
fi


# Get dependency binaries
GSBIN=$(which gs 2>/dev/null)
BCBIN=$(which bc 2>/dev/null)


# Verbose scale info
vprint "  Scale factor: $SCALE"


# Validate args
[[ $# -lt 1 ]] && { usage; exit 1; }
INFILEPDF="$1"
[[ "$INFILEPDF" =~ ^..*\.pdf$ ]] || { usage; exit 2; }
vprint "    Input file: $INFILEPDF"


# Parse output filename
if [[ -z $2 ]]; then
        OUTFILEPDF="${INFILEPDF%.pdf}.SCALED.pdf"
else
        OUTFILEPDF="${2%.pdf}.pdf"
fi
vprint "   Output file: $OUTFILEPDF"


# Set PGWIDTH and PGHEIGHT
if [[ $USEIMGMGK -eq $TRUE ]]; then
        getPageSizeImagemagick
else
        getPageSize
fi
vprint "         Width: $PGWIDTH postscript-points"
vprint "        Height: $PGHEIGHT postscript-points"


# Compute translation factors (to center page.
XTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGWIDTH" | "$BCBIN")
YTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGHEIGHT" | "$BCBIN")
vprint " Translation X: $XTRANS"
vprint " Translation Y: $YTRANS"


# Do it.
"$GSBIN" \
-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dSAFER \
-dCompatibilityLevel="1.5" -dPDFSETTINGS="/printer" \
-dColorConversionStrategy=/LeaveColorUnchanged \
-dSubsetFonts=true -dEmbedAllFonts=true \
-dDEVICEWIDTH=$PGWIDTH -dDEVICEHEIGHT=$PGHEIGHT \
-sOutputFile="$OUTFILEPDF" \
-c "<</BeginPage{$SCALE $SCALE scale $XTRANS $YTRANS translate}>> setpagedevice" \
-f "$INFILEPDF"
