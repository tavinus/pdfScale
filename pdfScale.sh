#!/bin/bash

# pdfScale.sh
#
# Scale PDF to specified percentage of original size.
# Ref: http://ma.juii.net/blog/scale-page-content-of-pdf-files.

SCALE=0.95 # scaling factor (0.95 = 95%, e.g.)

# Validate args.
[ $# -eq 1 ] || { echo "***ERROR: Usage pdfScale.sh <inFile>.pdf"; exit 99; }
INFILEPDF="$1"
[[ "$INFILEPDF" =~ ^..*\.pdf$ ]] || { echo "***ERROR: Usage pdfScale.sh <inFile>.pdf"; exit 99; }
OUTFILEPDF=$(echo "$INFILEPDF" | sed -e s/\.pdf$// -).SCALED.pdf

# Dependencies
command -v identify >/dev/null 2>&1 || { echo >&2 "Please install 'imagemagick' (sudo apt-get install imagemagick).  Aborting."; exit 1; }
command -v gs >/dev/null 2>&1 || { echo >&2 "Please install 'ghostscript' (sudo apt-get install ghostscript ?).  Aborting."; exit 1; }
command -v bc >/dev/null 2>&1 || { echo >&2 "Please install 'bc' arbitrary precision calculator language.  Aborting."; exit 1; }

# Get width/height in postscript points (1/72-inch), via ImageMagick identify command.
# (Alternatively, could use Poppler pdfinfo command; or grep/sed the PDF by hand.)
IDENTIFY=($(identify $INFILEPDF 2>/dev/null)) # bash array
[ $? -ne 0 ] &GEOMETRY=($(echo ${IDENTIFY[2]} | tr "x" " ")) # bash array — $IDENTIFY[2] is of the form PGWIDTHxPGHEIGHT
PGWIDTH=${GEOMETRY[0]}; PGHEIGHT=${GEOMETRY[1]}

# Compute translation factors (to center page.
XTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGWIDTH" | bc)
YTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGHEIGHT" | bc)

echo $PGWIDTH , $PGHEIGHT , $OUTFILEPDF , $SCALE , $XTRANS , $YTRANS , $INFILEPDF , $OUTFILEPDF

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