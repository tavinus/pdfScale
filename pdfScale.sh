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


###################################################
# PAGESIZE LOGIC
# 1- Try to get Mediabox with CAT/GREP
#    Remove /BBox search as it is unreliable
# 2- MacOS => try to use mdls
#    Linux => try to use pdfinfo
# 3- Try to use identify (imagemagick)
# 4- Fail
#    Remove postscript method, 
#    may have licensing problems
###################################################


VERSION="1.4.7"
SCALE="0.95"               # scaling factor (0.95 = 95%, e.g.)
VERBOSE=0                  # verbosity Level
BASENAME="$(basename $0)"  # simplified name of this script

# Set with which after we check dependencies
GSBIN=""                   # GhostScript Binaries
BCBIN=""                   # BC Math binary
IDBIN=""                   # Identify Binary
PDFINFOBIN=""              # PDF Info Binary
MDLSBIN=""                 # MacOS mdls binary

OSNAME="$(uname 2>/dev/null)" # Check where we are running

LC_MEASUREMENT="C"         # To make sure our numbers have .decimals
LC_ALL="C"                 # Some languages use , as decimal token
LC_CTYPE="C"
LC_NUMERIC="C"

TRUE=0                     # Silly stuff
FALSE=1

ADAPTIVEMODE=$TRUE         # Automatically try to guess best mode
MODE=""


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
Usage: $BASENAME [-v] [-s <factor>] [-m <mode>] <inFile.pdf> [outfile.pdf]
       $BASENAME -h
       $BASENAME -V

Parameters:
 -v          Verbose mode, prints extra information
             Use twice for even more information
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
 -m <mode>   Force a mode of page size detection. 
             Will disable the Adaptive Mode.
 -s <factor> Changes the scaling factor, defaults to 0.95
             MUST be a number bigger than zero. 
             Eg. -s 0.8 for 80% of the original size 

Modes:
 a, adaptive  Default mode, tries all the methods below
 c, cat+grep  Forces the use of the cat + grep method
 m, mdls      Forces the use of MacOS Quartz mdls
 p, pdfinfo   Forces the use of Linux PdfInfo
 i, identify  Forces the use of ImageMagick's Identify

Notes:
 - Adaptive Page size detection will try different modes until
   it gets a page size. You can force a mode with -m 'mode'
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
 $BASENAME -m pdfinfo -s 0.80 -v myPdfFile.pdf
 $BASENAME -v -v -m i -s 0.7 myPdfFile.pdf
 $BASENAME -h
"
}


# Prints usage info
usage() { 
        printVersion 2
        echo >&2 "Usage: $BASENAME [-v] [-s <factor>] [-m <mode>] <inFile.pdf> [outfile.pdf]"
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


# Parse a forced mode of operation
parseMode() {
        if [[ -z $1 ]]; then
                echo "Mode is empty, please specify the desired mode"
                echo "Falling back to adaptive mode!"
                ADAPTIVEMODE=$TRUE
                MODE=""
                return $FALSE
        fi
        
        if [[ $1 = 'c' || $1 = 'catgrep' || $1 = 'cat+grep' || $1 = 'CatGrep' || $1 = 'C' || $1 = 'CATGREP' ]]; then
                ADAPTIVEMODE=$FALSE
                MODE="CATGREP"
                return $TRUE
        elif [[ $1 = 'i' || $1 = 'imagemagick' || $1 = 'identify' || $1 = 'ImageMagick' || $1 = 'Identify' || $1 = 'I' || $1 = 'IDENTIFY' ]]; then
                ADAPTIVEMODE=$FALSE
                MODE="IDENTIFY"
                return $TRUE
        elif [[ $1 = 'm' || $1 = 'mdls' || $1 = 'MDLS' || $1 = 'quartz' || $1 = 'mac' || $1 = 'M' ]]; then
                ADAPTIVEMODE=$FALSE
                MODE="MDLS"
                return $TRUE
        elif [[ $1 = 'p' || $1 = 'pdfinfo' || $1 = 'PDFINFO' || $1 = 'PdfInfo' || $1 = 'P' ]]; then
                ADAPTIVEMODE=$FALSE
                MODE="PDFINFO"
                return $TRUE
        elif [[ $1 = 'a' || $1 = 'adaptive' || $1 = 'automatic' || $1 = 'A' || $1 = 'ADAPTIVE' || $1 = 'AUTOMATIC' ]]; then
                ADAPTIVEMODE=$TRUE
                MODE=""
                return $TRUE
        else
                echo "Invalid mode: $1"
                echo "Falling back to adaptive mode!"
                ADAPTIVEMODE=$TRUE
                MODE=""
                return $FALSE
        fi
        
        return $FALSE
}


# Gets page size using imagemagick's identify
getPageSizeImagemagick() {
        # Sanity
        if [[ ! -f $IDBIN && $ADAPTIVEMODE = $FALSE ]]; then
                echo "Error! ImageMagick's Identify was not found!"
                echo "Make sure you installed ImageMagick and have identify on your \$PATH"
                echo "Aborting! You may want to try the adaptive mode."
                exit 15
        elif [[ ! -f $IDBIN && $ADAPTIVEMODE = $TRUE ]]; then
                return $FALSE
        fi
        
        # get data from image magick
        local identify="$("$IDBIN" -format '%[fx:w] %[fx:h]BREAKME' "$INFILEPDF" 2>/dev/null)"
        # No page size data available
        
        if [[ -z $identify && $ADAPTIVEMODE = $FALSE ]]; then
                echo "Error when reading input file!"
                echo "Could not determine the page size!"
                echo "ImageMagicks's Identify returned an empty string!"
                echo "Aborting! You may want to try the adaptive mode."
                exit 15
        elif [[ -z $identify && $ADAPTIVEMODE = $TRUE ]]; then
                return $FALSE
        fi

        identify="${identify%%BREAKME*}"   # get page size only for 1st page
        identify=($identify)               # make it an array
        PGWIDTH=$(printf '%.0f' "${identify[0]}")             # assign
        PGHEIGHT=$(printf '%.0f' "${identify[1]}")            # assign
}


# Gets page size using Mac Quarts mdls
getPageSizeMdls() {
        # Sanity
        if [[ ! -f $MDLSBIN && $ADAPTIVEMODE = $FALSE ]]; then
                echo "Error! Mac Quartz mdls was not found!"
                echo "Are you even trying this on a Mac?"
                echo "Aborting! You may want to try the adaptive mode."
                exit 15
        elif [[ ! -f $MDLSBIN && $ADAPTIVEMODE = $TRUE ]]; then
                return $FALSE
        fi
        
        # get data from mdls
        local identify="$("$MDLSBIN" -mdls -name kMDItemPageHeight -name kMDItemPageWidth "$INFILEPDF" 2>/dev/null)"
        
        if [[ -z $identify && $ADAPTIVEMODE = $FALSE ]]; then
                echo "Error when reading input file!"
                echo "Could not determine the page size!"
                echo "Mac Quartz mdls returned an empty string!"
                echo "Aborting! You may want to try the adaptive mode."
                exit 15
        elif [[ -z $identify && $ADAPTIVEMODE = $TRUE ]]; then
                return $FALSE
        fi
        

        identify=${identify//$'\t'/ }      # change tab to space
        identify=($identify)               # make it an array
        
        PGWIDTH=$(printf '%.0f' "${identify[2]}")             # assign
        PGHEIGHT=$(printf '%.0f' "${identify[5]}")            # assign
}


# Gets page size using Linux PdfInfo
getPageSizePdfInfo() {
        # Sanity
        if [[ ! -f $PDFINFOBIN && $ADAPTIVEMODE = $FALSE ]]; then
                echo "Error! Linux pdfinfo was not found!"
                echo "Do you have pdfinfo installed and available on your \$PATH?"
                echo "Aborting! You may want to try the adaptive mode."
                exit 15
        elif [[ ! -f $PDFINFOBIN && $ADAPTIVEMODE = $TRUE ]]; then
                return $FALSE
        fi
        
        # get data from image magick
        local identify="$("$PDFINFOBIN" "$INFILEPDF" 2>/dev/null | grep -i 'Page size:' )"

        if [[ -z $identify && $ADAPTIVEMODE = $FALSE ]]; then
                echo "Error when reading input file!"
                echo "Could not determine the page size!"
                echo "Linux PdfInfo returned an empty string!"
                echo "Aborting! You may want to try the adaptive mode."
                exit 15
        elif [[ -z $identify && $ADAPTIVEMODE = $TRUE ]]; then
                return $FALSE
        fi

        identify="${identify##*Page size:}"  # remove stuff
        identify=($identify)                 # make it an array
        
        PGWIDTH=$(printf '%.0f' "${identify[0]}")             # assign
        PGHEIGHT=$(printf '%.0f' "${identify[2]}")            # assign
}


# Gets page size using cat and grep
getPageSizeCatGrep() {
        # get MediaBox info from PDF file using cat and grep, these are all possible
        # /MediaBox [0 0 595 841]
        # /MediaBox [ 0 0 595.28 841.89]
        # /MediaBox[ 0 0 595.28 841.89 ]

        # Get MediaBox data if possible
        local mediaBox="$(cat "$INFILEPDF" | grep -a '/MediaBox' | head -n1)"
        mediaBox="${mediaBox##*/MediaBox}"

        # No page size data available
        if [[ -z $mediaBox && $ADAPTIVEMODE = $FALSE ]]; then
                echo "Error when reading input file!"
                echo "Could not determine the page size!"
                echo "There is no MediaBox in the pdf document!"
                echo "Aborting! You may want to try the adaptive mode."
                exit 15
        elif [[ -z $mediaBox && $ADAPTIVEMODE = $TRUE ]]; then
                return $FALSE
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

        return $TRUE
}


# Detects operation mode and also runs the adaptive mode
getPageSize() {
        if [[ $ADAPTIVEMODE = $FALSE ]]; then
                vprint " Adaptive mode: Disabled"
                if [[ $MODE = "CATGREP" ]]; then
                        vprint "        Method: Cat + Grep"
                        getPageSizeCatGrep
                elif [[ $MODE = "MDLS" ]]; then
                        vprint "        Method: Mac Quartz mdls"
                        getPageSizeMdls
                elif [[ $MODE = "PDFINFO" ]]; then
                        vprint "        Method: Linux PdfInfo"
                        getPageSizePdfInfo
                elif [[ $MODE = "IDENTIFY" ]]; then
                        vprint "        Method: ImageMagick's Identify"
                        getPageSizeImagemagick
                else
                        echo "Error! Invalid Mode: $MODE"
                        echo "Aborting execution..."
                        exit 20
                fi
                return $TRUE
        fi
        
        vprint " Adaptive mode: Enabled"
        vprint "        Method: Cat + Grep"
        getPageSizeCatGrep
        if [[ -z $PGWIDTH && -z $PGHEIGHT ]]; then
                vprint "                Failed"
                if [[ $OSNAME = "Darwin" ]]; then
                        vprint "        Method: Mac Quartz mdls"
                        getPageSizeMdls
                else
                        vprint "        Method: Linux PdfInfo"
                        getPageSizePdfInfo
                fi
        fi
        
        if [[ -z $PGWIDTH && -z $PGHEIGHT ]]; then
                vprint "                Failed"
                vprint "        Method: ImageMagick's Identify"
                getPageSizeImagemagick
        fi
        
        if [[ -z $PGWIDTH && -z $PGHEIGHT ]]; then
                vprint "                Failed"
                echo "Error when detecting PDF paper size!"
                echo "All methods of detection failed"
                echo "You may want to install pdfinfo or imagemagick"
                exit 17
        fi
}


# Parse options
while getopts ":vhVs:m:" o; do
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
        m)
            parseMode ${OPTARG}
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
if [[ $MODE = "IDENTIFY" ]]; then
        vprint "Checking for imagemagick's identify"
        command -v identify >/dev/null 2>&1 || printDependency 'imagemagick'
fi
if [[ $MODE = "PDFINFO" ]]; then
        vprint "Checking for pdfinfo"
        command -v pdfinfo >/dev/null 2>&1 || printDependency 'pdfinfo'
fi


# Get dependency binaries
GSBIN="$(which gs 2>/dev/null)"
BCBIN="$(which bc 2>/dev/null)"
IDBIN=$(which identify 2>/dev/null)
if [[ $OSNAME = "Darwin" ]]; then
        MDLSBIN="$(which mdls 2>/dev/null)"
else
        PDFINFOBIN="$(which pdfinfo 2>/dev/null)"
fi


# Verbose scale info
vprint "  Scale factor: $SCALE"


# Validate args
[[ $# -lt 1 ]] && { usage; exit 1; }
INFILEPDF="$1"
[[ "$INFILEPDF" =~ ^..*\.pdf$ ]] || { usage; exit 2; }
[[ -f "$INFILEPDF" ]] || { echo "Error! File not found: $INFILEPDF"; exit 3; }
vprint "    Input file: $INFILEPDF"


# Parse output filename
if [[ -z $2 ]]; then
        OUTFILEPDF="${INFILEPDF%.pdf}.SCALED.pdf"
else
        OUTFILEPDF="${2%.pdf}.pdf"
fi
vprint "   Output file: $OUTFILEPDF"


getPageSize
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
