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


VERSION="1.3.5"
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
USECATGREP=$FALSE          # Use old cat + grep method


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
Usage: $BASENAME [-v] [-s <factor>] [-i|-c] <inFile.pdf> [outfile.pdf]
       $BASENAME -h
       $BASENAME -V

Parameters:
 -v          Verbose mode, prints extra information
             Use twice for even more information
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
 -i          Use imagemagick to get page size, 
             instead of postscript method
 -c          Use cat + grep to get page size, 
             instead of postscript method
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
	PGWIDTH=$(printf '%.0f' "${identify[0]}")             # assign
	PGHEIGHT=$(printf '%.0f' "${identify[1]}")            # assign
}



# Gets page size using toolbin_pdfinfo.ps
getPageSizeGS() {
	local PDFINFOGS=''
	read -r -d '' PDFINFOGS <<'EOF'
%!PS
% Copyright (C) 2001-2012 Artifex Software, Inc.
% All Rights Reserved.
%
% This software is provided AS-IS with no warranty, either express or
% implied.
%
% This software is distributed under license and may not be copied,
% modified or distributed except as expressly authorized under the terms
% of the license contained in the file LICENSE in this distribution.
%
% Refer to licensing information at http://www.artifex.com or contact
% Artifex Software, Inc.,  7 Mt. Lassen Drive - Suite A-134, San Rafael,
% CA  94903, U.S.A., +1(415)492-9861, for further information.
%
%
% $Id: pdf_info.ps 6300 2005-12-28 19:56:24Z alexcher $

% Dump some info from a PDF file

% usage: gs -dNODISPLAY -q -sFile=____.pdf [-dDumpMediaSizes=false] [-dDumpFontsNeeded=false] [-dDumpXML]
%                                          [-dDumpFontsUsed [-dShowEmbeddedFonts] ] toolbin/pdf_info.ps

128 dict begin

/QUIET true def		% in case they forgot

/showoptions {
  (           where "options" are:) =
  (           -dDumpMediaSizes=false    (default true) MediaBox and CropBox for each page) =
  (           -dDumpFontsNeeded=false   (default true)Fonts used, but not embedded) =
  (           -dDumpXML                 print the XML Metadata from the PDF, if present) =
  (           -dDumpFontsUsed           List all fonts used) =
  (           -dShowEmbeddedFonts       only meaningful with -dDumpFontsUsed) =
  (\n          If no options are given, the default is -dDumpMediaSizes -dDumpFontsNeeded) =
  () =
  flush
} bind def

/DumpMediaSizes where { pop } { /DumpMediaSizes true def } ifelse
/DumpFontsNeeded where { pop } { /DumpFontsNeeded true def } ifelse

[ shellarguments
  { counttomark 1 eq {
      dup 0 get (-) 0 get ne {
        % File specified on the command line using:  -- toolbin/pdf_info.ps infile.pdf
        /File exch def
        false	% dont show usage
      } {
        true	% show usage and quit
      } ifelse
    } { true } ifelse
    {
      (\n*** Usage: gs [options] -- toolbin/pdf_info.ps infile.pdf  ***\n\n) print
      showoptions
      quit
    } if
  } if

/File where not {
  (\n   *** Missing input file name \(use -sFile=____.pdf\)\n) =
  (    usage: gs -dNODISPLAY -q -sFile=____.pdf [ options ] toolbin/pdf_info.ps\n) =
  showoptions
  quit
} if
cleartomark		% discard the dict from --where--

% ---- No more executable code on the top level after this line -----
% ---- except 2 lines at the very end                           -----

/printXML {	% <string> printXML -
  % print non-blank lines without trailing spaces
  dup dup length 1 sub -1 0 {
    1 index 1 index get 32 eq {
      0 exch getinterval exch
    } {
      exch = exit	% non-blank on this line
    }
    ifelse
  } for
  pop pop		% clean up
} bind def

/dump-pdf-info {    % (fname) -> -
  () = (        ) print print ( has ) print 
  PDFPageCount dup =print 10 mod 1 eq { ( page.\n) } { ( pages\n) } ifelse = flush

  /DumpXML where {
    pop
    Trailer /Root oget /Metadata knownoget {
      //false resolvestream
      { dup 256 string readline exch printXML not { exit } if } loop
      pop		% done with the stream
      (_____________________________________________________________) =
      flush
    } if
  } if

  % Print out the "Info" dictionary if present
  Trailer /Info knownoget {
     dup /Title knownoget { (Title: ) print = flush } if
     dup /Author knownoget { (Author: ) print = flush } if
     dup /Subject knownoget { (Subject: ) print = flush } if
     dup /Keywords knownoget { (Keywords: ) print = flush } if
     dup /Creator knownoget { (Creator: ) print = flush } if
     dup /Producer knownoget { (Producer: ) print = flush } if
     dup /CreationDate knownoget { (CreationDate: ) print = flush } if
     dup /ModDate knownoget { (ModDate: ) print = flush } if
     dup /Trapped knownoget { (Trapped: ) print = flush } if
     pop
  } if
} bind def

% <page index> <page dict> dump-media-sizes -
/dump-media-sizes {
  DumpMediaSizes {
    () =
    % Print out the Page Size info for each page.
    (Page ) print =print
    dup /UserUnit pget {
      ( UserUnit: ) print =print
    } if
    dup /MediaBox pget {
      ( MediaBox: ) print oforce_array ==only
    } if
    dup /CropBox pget {
      ( CropBox: ) print oforce_array ==only
    } if
    dup /BleedBox pget {
      ( BleedBox: ) print oforce_array ==only
    } if
    dup /TrimBox pget {
      ( TrimBox: ) print oforce_array ==only
    } if
    dup /ArtBox pget {
      ( ArtBox: ) print oforce_array ==only
    } if
    dup /Rotate pget {
       (    Rotate = ) print =print
    } if
    dup /Annots pget {
       pop
        (     Page contains Annotations) print
    } if
    pageusestransparency {
        (     Page uses transparency features) print
    } if
    () = flush
  }
  {
    pop pop
  } ifelse
} bind def

% List of standard font names for use when we are showing the FontsNeeded
/StdFontNames [
 /Times-Roman /Helvetica /Courier /Symbol
 /Times-Bold /Helvetica-Bold /Courier-Bold /ZapfDingbats
 /Times-Italic /Helvetica-Oblique /Courier-Oblique
 /Times-BoldItalic /Helvetica-BoldOblique /Courier-BoldOblique
] def

/res-type-dict 10 dict begin
  /Font {
    { 
      exch pop oforce 
      dup //null ne {
        dup /DescendantFonts knownoget {
           exch pop 0 get oforce
        } if
        dup /FontDescriptor knownoget {
          dup /FontFile known 1 index /FontFile2 known or exch /FontFile3 known or
          /ShowEmbeddedFonts where { pop pop //false } if {
            pop			% skip embedded fonts
          } {
            /BaseFont knownoget { %  not embedded
              2 index exch //null put
            } if
          } ifelse
        } {
          /BaseFont knownoget { % no FontDescriptor, not embedded
            2 index exch //null put
          } if
        } ifelse
      } {
        pop
      } ifelse
    } forall	% traverse the dictionary
  } bind def

  /XObject {
    { 
      exch pop oforce
      dup //null ne {
        dup /Subtype knownoget {
          /Form eq {
            /Resources knownoget {
              get-fonts-from-res
            } if
          } {
            pop
          } ifelse
        } {
          pop
        } ifelse
      } {
        pop
      } ifelse
    } forall
  } bind def
  
  /Pattern {
    { 
      exch pop oforce
      dup //null ne {
        /Resources knownoget {
          get-fonts-from-res
        } if
      } {
        pop
      } ifelse
    } forall
  } bind def
currentdict end readonly def

% <dict for fonts> <<res-dict>> get-fonts-from-res -
/get-fonts-from-res {
  oforce 
  dup //null ne {
    { 
      oforce
      dup //null ne {
        //res-type-dict 3 -1 roll 
        .knownget {
          exec
        } {
          pop
        } ifelse
      } {
        pop pop
      } ifelse
    } forall
  } {
    pop
  } ifelse
} bind def

currentdict /res-type-dict undef

/getPDFfonts {	%	<dict for fonts> <page dict> getPDFfonts -
  dup /Resources pget { get-fonts-from-res } if
  /Annots knownoget {
    { oforce
      dup //null ne {
        /AP knownoget {
          { exch pop oforce
            dup //null ne {
              dup /Resources knownoget {
                get-fonts-from-res
              } if
              { exch pop oforce
                dup type /dicttype eq {
                  /Resources knownoget {
                    get-fonts-from-res
                  } if
                } {
                  pop
                } ifelse
              } forall
            } {
              pop
            } ifelse
          } forall
        } if
      } {
        pop
      } ifelse
    } forall
  } if
  pop
} bind def

/dump-fonts-used { % <dict for fonts> dump-fonts-used -
  % If DumpFontsUsed is not true, then remove the "standard" fonts from the list
  systemdict /DumpFontsUsed known not {
    StdFontNames {
      1 index 1 index known { 1 index 1 index undef } if
      pop
    } forall
  } if

  % Now dump the FontsUsed dict into an array so we can sort it.
  [ 1 index { pop } forall ]
  { 100 string cvs exch 100 string cvs exch lt } .sort

  systemdict /DumpFontsUsed known
  {
    (\nFont or CIDFont resources used:) =
    { = } forall
  } {
    DumpFontsNeeded {
      dup length 0 gt {
        (\nFonts Needed that are not embedded \(system fonts required\):) =
        { (    ) print = } forall
      } {
        pop
        (\nNo system fonts are needed.) =
      } ifelse
    } {
      pop
    } ifelse
  } ifelse
  pop
} bind def

% Copy selected subfiles to temporary files and return the file names
% as a PostScript names to protect them from restore.
% Currently, all PDF files in the Portfolio are extracted and returned.
%
% - pdf_collection_files [ /temp_file_name ... /temp_file_name
/pdf_collection_files {
  mark
  Trailer /Root oget
  dup /Collection oknown {
    /Names knownoget {
      /EmbeddedFiles knownoget {
        pdf_collection_names
      } if
    } if
  } {
    pop
  } ifelse
} bind def

% Output all the info about the file
/dump {  % (title) -> -
  /PDFPageCount pdfpagecount def
  dump-pdf-info
  % dict will be populated with fonts through a call to "getPDFfonts"
  % per page, then the contents dumped out in "dump-fonts-used"
  1000 dict

  1 1 PDFPageCount
  {
    dup pdfgetpage dup 3 -1 roll
    dump-media-sizes
    1 index exch getPDFfonts
  } for

  dump-fonts-used

} bind def

% Choose between collection vs plain file.
% Enumerate collections and apply the dump procedure.
/enum-pdfs {		% - -> -
  File (r) file runpdfbegin
  pdf_collection_files
  dup mark eq {
    pop
    File dump
    runpdfend
  } {
    runpdfend
    ] 0 1 2 index length 1 sub {
        2 copy get exch           %  [file ... ] file i
        1 add (0123456789) cvs    %  [file ... ] file (i+1)
        File exch ( part ) exch concatstrings concatstrings
        exch                      %  [file ... ] (fname part i+1) file
        dup type /filetype eq {
          runpdfbegin
          dump
          runpdfend
          closefile
        } {
          .namestring
          dup (r) file
          runpdfbegin
          exch dump
          runpdfend
          deletefile
        } ifelse
    } for
    pop
  } ifelse
} bind def

enum-pdfs
end
quit

EOF
	# get data from gs script
        local identify="$("$GSBIN" -dNODISPLAY -q -sFile="$INFILEPDF" -dDumpMediaSizes -dDumpFontsNeeded=false -c "$PDFINFOGS" 2>/dev/null | grep MediaBox | head -n1)"

	echo "identify: $identify"

	identify="${identify##*MediaBox:}"   # get page size only for 1st page

        # remove chars [ and ]
        identify="${identify//[}"
        identify="${identify//]}"

	identify=($identify)               # make it an array
	
	echo "identify: ${identify[@]}"

        # sanity
        if [[ ${#identify[@]} -lt 4 ]]; then 
            echo "Error when reading the page size!"
            echo "The page size information is invalid!"
            exit 16
        fi

	PGWIDTH=$(printf '%.0f' "${identify[2]}")             # assign
	PGHEIGHT=$(printf '%.0f' "${identify[3]}")            # assign
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
while getopts ":vichVs:" o; do
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
            USECATGREP=$FALSE
            ;;
        c)
            USECATGREP=$TRUE
            USEIMGMGK=$FALSE
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
[[ -f "$INFILEPDF" ]] || { echo "Error! File not found: $INFILEPDF"; exit 3; }
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
elif [[ $USECATGREP -eq $TRUE ]]; then
	getPageSize
else
        getPageSizeGS
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
