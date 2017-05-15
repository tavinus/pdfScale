#!/usr/bin/env bash

# pdfScale.sh
#
# Scale PDF to specified percentage of original size.
#
# Gustavo Arnosti Neves - 2016 / 07 / 10
#        Latest Version - 2017 / 05 / 14
#
# This script: https://github.com/tavinus/pdfScale
#    Based on: http://ma.juii.net/blog/scale-page-content-of-pdf-files
#         And: https://gist.github.com/MichaelJCole/86e4968dbfc13256228a


VERSION="2.0.0"


###################### EXTERNAL PROGRAMS #######################

GSBIN=""                       # GhostScript Binary
BCBIN=""                       # BC Math Binary
IDBIN=""                       # Identify Binary
PDFINFOBIN=""                  # PDF Info Binary
MDLSBIN=""                     # MacOS mdls Binary


##################### ENVIRONMENT SET-UP #######################

LC_MEASUREMENT="C"         # To make sure our numbers have .decimals
LC_ALL="C"                 # Some languages use , as decimal token
LC_CTYPE="C"
LC_NUMERIC="C"

TRUE=0                     # Silly stuff
FALSE=1

########################### GLOBALS ############################

SCALE="0.95"                   # scaling factor (0.95 = 95%, e.g.)
VERBOSE=0                      # verbosity Level
PDFSCALE_NAME="$(basename $0)" # simplified name of this script
OSNAME="$(uname 2>/dev/null)"  # Check where we are running

JUST_IDENTIFY=$FALSE        # Flag to just show PDF info
ADAPTIVEMODE=$TRUE          # Automatically try to guess best mode
AUTOMATIC_SCALING=$TRUE     # Default scaling in $SCALE, override by resize mode
MODE=""                     # Which page size detection to use
RESIZE_PAPER_TYPE=""        # Pre-defined paper to use
CUSTOM_RESIZE_PAPER=$FALSE  # If we are using a custom-defined paper
FLIP_DETECTION=$TRUE        # If we shoudl run the Flip-detection
FLIP_FORCE=$FALSE           # If we should force Flipping
AUTO_ROTATION='/PageByPage' # GS cal auto-rotation setting
PGWIDTH=""                  # Input PDF Page Width
PGHEIGHT=""                 # Input PDF Page Height
RESIZE_WIDTH=""             # Resized PDF Page Width
RESIZE_HEIGHT=""            # Resized PDF Page Height


########################## EXIT FLAGS ##########################

EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_INVALID_PAGE_SIZE_DETECTED=10
EXIT_FILE_NOT_FOUND=20
EXIT_INPUT_NOT_PDF=21
EXIT_INVALID_OPTION=22
EXIT_NO_INPUT_FILE=23
EXIT_INVALID_SCALE=24
EXIT_MISSING_DEPENDENCY=25
EXIT_IMAGEMAGIK_NOT_FOUND=26
EXIT_MAC_MDLS_NOT_FOUND=27
EXIT_PDFINFO_NOT_FOUND=28
EXIT_TEMP_FILE_EXISTS=40
EXIT_INVALID_PAPER_SIZE=50


############################# MAIN #############################

# Main function called at the end
main() {
        checkDeps
        printPDFSizes
        vprint "    Input File: $INFILEPDF"
        vprint "   Output File: $OUTFILEPDF"
        getPageSize
        vPrintPageSizes ' Source'
        local finalRet=$EXIT_ERROR
        local tempFile=""
        local tempSuffix="$RANDOM$RANDOM""_TEMP_$RANDOM$RANDOM.pdf"

        if isMixedMode; then
                outputFile="$OUTFILEPDF"                    # backup outFile name
                tempFile="${OUTFILEPDF%.pdf}.$tempSuffix"   # set a temp file name
                if isFile "$tempFile"; then
                        printError $'Error! Temporary file name already exists!\n'"File: $tempFile"$'\nAborting execution to avoid overwriting the file.\nPlease Try again...'
                        exit $EXIT_TEMP_FILE_EXISTS
                fi
                OUTFILEPDF="$tempFile"                      # set output to tmp file
                pageResize                                  # resize to tmp file
                finalRet=$?
                INFILEPDF="$tempFile"                       # get tmp file as input
                OUTFILEPDF="$outputFile"                    # reset final target
                PGWIDTH=$RESIZE_WIDTH                       # we already know the new page size
                PGHEIGHT=$RESIZE_HEIGHT                     # from the last command (Resize)
                vPrintPageSizes '    New'
                vPrintScaleFactor
                pageScale                                   # scale the resized pdf
                finalRet=$(($finalRet+$?))
                                                            # remove tmp file
                rm "$tempFile" >/dev/null 2>&1 || printError "Error when removing temporary file: $tempFile"
        elif isResizeMode; then
                vPrintScaleFactor "Disabled (resize only)"
                pageResize
                finalRet=$?
        else
                local scaleMode=""
                isManualScaledMode && scaleMode='(manual)' || scaleMode='(auto)'
                vPrintScaleFactor "$SCALE $scaleMode"
                pageScale
                finalRet=$?
        fi

        if [[ finalRet -eq $EXIT_SUCCESS ]]; then
                vprint "  Final Status: File created successfully"
        else
                vprint "  Final Status: Errors were detected. Exit status: $finalRet"
        fi

        return $finalRet
}

# Prints PDF Info and exits with $EXIT_SUCCESS, but only if $JUST_IDENTIFY is $TRUE
printPDFSizes() {
        if [[ $JUST_IDENTIFY -eq $TRUE ]]; then
                VERBOSE=0
                printVersion 3 " - Paper Sizes"
                getPageSize || initError "Could not get pagesize!"
                local paperType="$(getGSPaperName $PGWIDTH $PGHEIGHT)"
                isEmpty "$paperType" && paperType="NOT Detected"
               #printf '%s\n' "-----+------+----WIDTH-+-HEIGHT-----------"
                printf '%s\n' "------------+-----------------------------"
                printf "       File | %s\n" "$(basename "$INFILEPDF")"
                printf " Paper Type | %s\n" "$paperType"
                printf '%s\n' "------------+-----------------------------"
               #printf '%s\n' "------------+----WIDTH-+-HEIGHT-----------"
                printf '%s\n' "            |    WIDTH x HEIGHT"
                printf "     Points | %+8s x %-8s\n" "$PGWIDTH" "$PGHEIGHT"
                printf " Milimeters | %+8s x %-8s\n" "$(pointsToMilimeters $PGWIDTH)" "$(pointsToMilimeters $PGHEIGHT)"
                printf "     Inches | %+8s x %-8s\n" "$(pointsToInches $PGWIDTH)" "$(pointsToInches $PGHEIGHT)"
                exit $EXIT_SUCCESS
        fi
        return $EXIT_SUCCESS
}

###################### GHOSTSCRIPT CALLS #######################

# Runs the ghostscript scaling script
pageScale() {
        # Compute translation factors (to center page).
        XTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGWIDTH" | "$BCBIN")
        YTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGHEIGHT" | "$BCBIN")
        vprint " Translation X: $XTRANS"
        vprint " Translation Y: $YTRANS"

        local increase=$(echo "scale=0; (($SCALE - 1) * 100)/1" | "$BCBIN")
        vprint "   Run Scaling: $increase %"

        # Scale page
        "$GSBIN" \
-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dSAFER \
-dCompatibilityLevel="1.5" -dPDFSETTINGS="/printer" \
-dColorConversionStrategy=/LeaveColorUnchanged \
-dSubsetFonts=true -dEmbedAllFonts=true \
-dDEVICEWIDTHPOINTS=$PGWIDTH -dDEVICEHEIGHTPOINTS=$PGHEIGHT \
-sOutputFile="$OUTFILEPDF" \
-c "<</BeginPage{$SCALE $SCALE scale $XTRANS $YTRANS translate}>> setpagedevice" \
-f "$INFILEPDF" 

        return $?
}


# Runs the ghostscript paper resize script
pageResize() {
        # Get new paper sizes if not custom paper
        isNotCustomPaper && getGSPaperSize "$RESIZE_PAPER_TYPE"

        vprint "   Auto Rotate: $(basename $AUTO_ROTATION)"

        # Flip detect
        local tmpInverter=""
        if [[ $FLIP_DETECTION -eq $TRUE || $FLIP_FORCE -eq $TRUE ]]; then
                if [[ $PGWIDTH -gt $PGHEIGHT && $RESIZE_WIDTH -lt $RESIZE_HEIGHT ]] || [[ $FLIP_FORCE -eq $TRUE ]]; then
                        [[ $FLIP_FORCE -eq $TRUE ]] && vprint "   Flip Detect: Forced Mode!" || vprint "   Flip Detect: Wrong orientation detected!"
                        vprint "                Inverting Width <-> Height"
                        tmpInverter=$RESIZE_HEIGHT
                        RESIZE_HEIGHT=$RESIZE_WIDTH
                        RESIZE_WIDTH=$tmpInverter
                else
                        vprint "   Flip Detect: No change needed"
                fi
        else
                vprint "   Flip Detect: Disabled"
        fi

        vprint "  Run Resizing: $(uppercase "$RESIZE_PAPER_TYPE") ( "$RESIZE_WIDTH" x "$RESIZE_HEIGHT" ) pts"

        # Change page size
        "$GSBIN" \
-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dSAFER \
-dCompatibilityLevel="1.5" -dPDFSETTINGS="/printer" \
-dColorConversionStrategy=/LeaveColorUnchanged \
-dSubsetFonts=true -dEmbedAllFonts=true \
-dDEVICEWIDTHPOINTS=$RESIZE_WIDTH -dDEVICEHEIGHTPOINTS=$RESIZE_HEIGHT \
-dAutoRotatePages=$AUTO_ROTATION \
-dFIXEDMEDIA -dPDFFitPage \
-sOutputFile="$OUTFILEPDF" \
-f "$INFILEPDF" 

        return $?
}


########################## INITIALIZERS #########################

# Loads external dependencies and checks for errors
initDeps() {
        GREPBIN="$(which grep 2>/dev/null)"
        GSBIN="$(which gs 2>/dev/null)"
        BCBIN="$(which bc 2>/dev/null)"
        IDBIN=$(which identify 2>/dev/null)
        MDLSBIN="$(which mdls 2>/dev/null)"
        PDFINFOBIN="$(which pdfinfo 2>/dev/null)"
        
        vprint "Checking for basename, grep, ghostscript and bcmath"
        basename "" >/dev/null 2>&1 || printDependency 'basename'
        notIsAvailable "$GREPBIN" && printDependency 'grep'
        notIsAvailable "$GSBIN" && printDependency 'ghostscript'
        notIsAvailable "$BCBIN" && printDependency 'bc'
        return $TRUE
}

# Checks for dependencies errors, run after getting options
checkDeps() {
        if [[ $MODE = "IDENTIFY" ]]; then
                vprint "Checking for imagemagick's identify"
                if notIsAvailable "$IDBIN"; then printDependency 'imagemagick'; fi
        fi
        if [[ $MODE = "PDFINFO" ]]; then
                vprint "Checking for pdfinfo"
                if notIsAvailable "$PDFINFOBIN"; then printDependency 'pdfinfo'; fi
        fi
        if [[ $MODE = "MDLS" ]]; then
                vprint "Checking for MacOS mdls"
                if notIsAvailable "$MDLSBIN"; then 
                        initError 'mdls executable was not found! Is this even MacOS?' $EXIT_MAC_MDLS_NOT_FOUND 'nobanner'
                fi
        fi
        return $TRUE
}


######################### CLI OPTIONS ##########################

# Parse options
getOptions() {
        while getopts ":vhVis:m:r:pf:a:" o; do
            case "${o}" in
                v)
                    ((VERBOSE++))
                    ;;
                h)
                    printHelp
                    exit $EXIT_SUCCESS
                    ;;
                V)
                    printVersion
                    exit $EXIT_SUCCESS
                    ;;
                i)
                    JUST_IDENTIFY=$TRUE
                    ;;
                s)
                    parseScale ${OPTARG}
                    ;;
                m)
                    parseMode ${OPTARG}
                    ;;
                r)
                    parsePaperResize ${OPTARG}
                    ;;
                p)
                    printPaperInfo
                    exit $EXIT_SUCCESS
                    ;;
                f)
                    parseFlipDetectionMode ${OPTARG}
                    ;;
                a)
                    parseAutoRotationMode ${OPTARG}
                    ;;
                *)
                    initError "Invalid Option: -$OPTARG" $EXIT_INVALID_OPTION
                    ;;
            esac
        done
        shift $((OPTIND-1))
        
        if [[ $JUST_IDENTIFY -eq $TRUE ]]; then
                VERBOSE=0
        fi
        
        # Validate input PDF file
        INFILEPDF="$1"
        isEmpty "$INFILEPDF" && initError "Input file is empty!" $EXIT_NO_INPUT_FILE
        isPDF "$INFILEPDF"   || initError "Input file is not a PDF file: $INFILEPDF" $EXIT_INPUT_NOT_PDF
        isFile "$INFILEPDF"  || initError "Input file not found: $INFILEPDF" $EXIT_FILE_NOT_FOUND
        
        printVersion 1 'verbose'
        if isMixedMode; then
                vprint "   Mixed Tasks: Resize & Scale"
                isEmpty "$2" && OUTFILEPDF="${INFILEPDF%.pdf}.$(uppercase $RESIZE_PAPER_TYPE).SCALED.pdf"
        elif isResizeMode; then
                vprint "   Single Task: Resize PDF Paper"
                isEmpty "$2" && OUTFILEPDF="${INFILEPDF%.pdf}.$(uppercase $RESIZE_PAPER_TYPE).pdf"
        else
                vprint "   Single Task: Scale PDF Contents"
                isEmpty "$2" && OUTFILEPDF="${INFILEPDF%.pdf}.SCALED.pdf"
        fi
        isNotEmpty "$2" && OUTFILEPDF="${2%.pdf}.pdf"
}


# Parses and validates the scaling factor
parseScale() {
        AUTOMATIC_SCALING=$FALSE
        if ! isFloatBiggerThanZero "$1"; then
                printError "Invalid factor: $1"
                printError "The factor must be a floating point number greater than 0"
                printError "Example: for 80% use 0.8"
                exit $EXIT_INVALID_SCALE
        fi
        SCALE="$1"
}

# Parse a forced mode of operation
parseMode() {
        local param="$(lowercase $1)"
        case "${param}" in
                c|catgrep|'cat+grep'|grep|g)
                        ADAPTIVEMODE=$FALSE
                        MODE="CATGREP"
                        return $TRUE
                        ;;
                i|imagemagick|identify)
                        ADAPTIVEMODE=$FALSE
                        MODE="IDENTIFY"
                        return $TRUE
                        ;;
                m|mdls|quartz|mac)
                        ADAPTIVEMODE=$FALSE
                        MODE="MDLS"
                        return $TRUE
                        ;;
                p|pdfinfo)
                        ADAPTIVEMODE=$FALSE
                        MODE="PDFINFO"
                        return $TRUE
                        ;;
                *)
                        ADAPTIVEMODE=$TRUE
                        MODE=""
                        if [[ "$param" != 'a' && "$param" != 'auto' && "$param" != 'automatic' && "$param" != 'adaptive' ]]; then
                                printError "Error! Invalid PDF Size Detection Mode: \"$1\", using adaptive mode!"
                                return $FALSE
                        fi
                        return $TRUE
                        ;;
        esac
        
        return $FALSE
}

# Parses and validates the scaling factor
parseFlipDetectionMode() {
        local param="$(lowercase $1)"
        case "${param}" in
                d|disable)
                        FLIP_DETECTION=$FALSE
                        FLIP_FORCE=$FALSE
                        ;;
                f|force)
                        FLIP_DETECTION=$FALSE
                        FLIP_FORCE=$TRUE
                        ;;
                *)
                        [[ "$param" != 'a' && "$param" != 'auto' ]] && printError "Error! Invalid Flip Detection Mode: \"$1\", using automatic mode!"
                        FLIP_DETECTION=$TRUE
                        FLIP_FORCE=$FALSE
                        ;;
        esac
}

# Parses and validates the scaling factor
parseAutoRotationMode() {
        local param="$(lowercase $1)"
        case "${param}" in
                n|none)
                        AUTO_ROTATION='/None'
                        ;;
                a|all)
                        AUTO_ROTATION='/All'
                        ;;
                p|pagebypage|auto)
                        AUTO_ROTATION='/PageByPage'
                        ;;
                *)
                        printError "Error! Invalid Auto Rotation Mode: $param, using default: $(basename $AUTO_ROTATION)"
                        ;;
        esac
}


################### PDF PAGE SIZE DETECTION ####################

################################################################
# Detects operation mode and also runs the adaptive mode
# PAGESIZE LOGIC
# 1- Try to get Mediabox with GREP
# 2- MacOS => try to use mdls
# 3- Try to use pdfinfo
# 4- Try to use identify (imagemagick)
# 5- Fail
################################################################
getPageSize() {
        if isNotAdaptiveMode; then
                vprint " Get Page Size: Adaptive Disabled"
                if [[ $MODE = "CATGREP" ]]; then
                        vprint "        Method: Grep"
                        getPageSizeCatGrep
                elif [[ $MODE = "MDLS" ]]; then
                        vprint "        Method: Mac Quartz mdls"
                        getPageSizeMdls
                elif [[ $MODE = "PDFINFO" ]]; then
                        vprint "        Method: PDFInfo"
                        getPageSizePdfInfo
                elif [[ $MODE = "IDENTIFY" ]]; then
                        vprint "        Method: ImageMagick's Identify"
                        getPageSizeImagemagick
                else
                        printError "Error! Invalid Mode: $MODE"
                        printError "Aborting execution..."
                        exit $EXIT_INVALID_OPTION
                fi
                return $TRUE
        fi
        
        vprint " Get Page Size: Adaptive Enabled"
        vprint "        Method: Grep"
        getPageSizeCatGrep
        if pageSizeIsInvalid && [[ $OSNAME = "Darwin" ]]; then
                vprint "                Failed"
                vprint "        Method: Mac Quartz mdls"
                getPageSizeMdls
        fi

        if pageSizeIsInvalid; then
                vprint "                Failed"
                vprint "        Method: PDFInfo"
                getPageSizePdfInfo
        fi

        if pageSizeIsInvalid; then
                vprint "                Failed"
                vprint "        Method: ImageMagick's Identify"
                getPageSizeImagemagick
        fi

        if pageSizeIsInvalid; then
                vprint "                Failed"
                printError "Error when detecting PDF paper size!"
                printError "All methods of detection failed"
                printError "You may want to install pdfinfo or imagemagick"
                exit $EXIT_INVALID_PAGE_SIZE_DETECTED
        fi

        return $TRUE
}

# Gets page size using imagemagick's identify
getPageSizeImagemagick() {
        # Sanity and Adaptive together
        if notIsFile "$IDBIN" && isNotAdaptiveMode; then
                notAdaptiveFailed "Make sure you installed ImageMagick and have identify on your \$PATH" "ImageMagick's Identify"
        elif notIsFile "$IDBIN" && isAdaptiveMode; then
                return $FALSE
        fi

        # get data from image magick
        local identify="$("$IDBIN" -format '%[fx:w] %[fx:h]BREAKME' "$INFILEPDF" 2>/dev/null)"
        
        if isEmpty "$identify" && isNotAdaptiveMode; then
                notAdaptiveFailed "ImageMagicks's Identify returned an empty string!"
        elif isEmpty "$identify" && isAdaptiveMode; then
                return $FALSE
        fi

        identify="${identify%%BREAKME*}"   # get page size only for 1st page
        identify=($identify)               # make it an array
        PGWIDTH=$(printf '%.0f' "${identify[0]}")             # assign
        PGHEIGHT=$(printf '%.0f' "${identify[1]}")            # assign

        return $TRUE
}


# Gets page size using Mac Quarts mdls
getPageSizeMdls() {
        # Sanity and Adaptive together
        if notIsFile "$MDLSBIN" && isNotAdaptiveMode; then
                notAdaptiveFailed "Are you even trying this on a Mac?" "Mac Quartz mdls"
        elif notIsFile "$MDLSBIN" && isAdaptiveMode; then
                return $FALSE
        fi

        local identify="$("$MDLSBIN" -mdls -name kMDItemPageHeight -name kMDItemPageWidth "$INFILEPDF" 2>/dev/null)"

        if isEmpty "$identify" && isNotAdaptiveMode; then
                notAdaptiveFailed "Mac Quartz mdls returned an empty string!"
        elif isEmpty "$identify" && isAdaptiveMode; then
                return $FALSE
        fi

        identify=${identify//$'\t'/ }      # change tab to space
        identify=($identify)               # make it an array

        if [[ "${identify[5]}" = "(null)" || "${identify[2]}" = "(null)" ]] && isNotAdaptiveMode; then
                notAdaptiveFailed "There was no metadata to read from the file! Is Spotlight OFF?"
        elif [[ "${identify[5]}" = "(null)" || "${identify[2]}" = "(null)" ]] && isAdaptiveMode; then
                return $FALSE
        fi

        PGWIDTH=$(printf '%.0f' "${identify[5]}")             # assign
        PGHEIGHT=$(printf '%.0f' "${identify[2]}")            # assign

        return $TRUE
}


# Gets page size using Linux PdfInfo
getPageSizePdfInfo() {
        # Sanity and Adaptive together
        if notIsFile "$PDFINFOBIN" && isNotAdaptiveMode; then
                notAdaptiveFailed "Do you have pdfinfo installed and available on your \$PATH?" "Linux pdfinfo"
        elif notIsFile "$PDFINFOBIN" && isAdaptiveMode; then
                return $FALSE
        fi

        # get data from image magick
        local identify="$("$PDFINFOBIN" "$INFILEPDF" 2>/dev/null | "$GREPBIN" -i 'Page size:' )"

        if isEmpty "$identify" && isNotAdaptiveMode; then
                notAdaptiveFailed "Linux PdfInfo returned an empty string!"
        elif isEmpty "$identify" && isAdaptiveMode; then
                return $FALSE
        fi

        identify="${identify##*Page size:}"  # remove stuff
        identify=($identify)                 # make it an array
        
        PGWIDTH=$(printf '%.0f' "${identify[0]}")             # assign
        PGHEIGHT=$(printf '%.0f' "${identify[2]}")            # assign

        return $TRUE
}


# Gets page size using cat and grep
getPageSizeCatGrep() {
        # get MediaBox info from PDF file using cat and grep, these are all possible
        # /MediaBox [0 0 595 841]
        # /MediaBox [ 0 0 595.28 841.89]
        # /MediaBox[ 0 0 595.28 841.89 ]

        # Get MediaBox data if possible
        #local mediaBox="$(cat "$INFILEPDF" | "$GREPBIN" -a '/MediaBox' | "$HEADBIN" -n1)"
        #local mediaBox="$("$GREPBIN" -a -e '/MediaBox' "$INFILEPDF" | "$HEADBIN" -n1)"
        local mediaBox="$("$GREPBIN" -a -e '/MediaBox' "$INFILEPDF" 2>/dev/null)"$'\n\n'
        while read l; do 
                mediaBox="$l"
                break
        done <<< "$mediaBox"

        mediaBox="${mediaBox##*/MediaBox}"

        # No page size data available
        if isEmpty "$mediaBox" && isNotAdaptiveMode; then
                notAdaptiveFailed "There is no MediaBox in the pdf document!"
        elif isEmpty "$mediaBox" && isAdaptiveMode; then
                return $FALSE
        fi

        # remove chars [ and ]
        mediaBox="${mediaBox//[}"
        mediaBox="${mediaBox//]}"

        mediaBox=($mediaBox)        # make it an array
        mbCount=${#mediaBox[@]}     # array size

        # sanity
        if [[ $mbCount -lt 4 ]]; then 
            printError "Error when reading the page size!"
            printError "The page size information is invalid!"
            exit $EXIT_INVALID_PAGE_SIZE_DETECTED
        fi

        # we are done
        PGWIDTH=$(printf '%.0f' "${mediaBox[2]}")  # Get Round Width
        PGHEIGHT=$(printf '%.0f' "${mediaBox[3]}") # Get Round Height

        return $TRUE
}

# Prints error message and exits execution
notAdaptiveFailed() {
        local errProgram="$2"
        local errStr="$1"
        if isEmpty "$2"; then
                printError "Error when reading input file!"
                printError "Could not determine the page size!"
        else
                printError "Error! $2 was not found!"
        fi
        isNotEmpty "$errStr" && printError "$errStr"
        printError "Aborting! You may want to try the adaptive mode."
        exit $EXIT_INVALID_PAGE_SIZE_DETECTED
}

# Verbose print of the Width and Height (Source or New) to screen
vPrintPageSizes() {
        vprint " $1 Width: $PGWIDTH postscript-points"
        vprint "$1 Height: $PGHEIGHT postscript-points"
}


#################### GHOSTSCRIPT PAPER INFO ####################

# Loads GS paper info to memory
getPaperInfo() {
        # name inchesW inchesH mmW mmH pointsW pointsH
        sizesUS="\
11x17 11.0 17.0 279 432 792 1224
ledger 17.0 11.0 432 279 1224 792
legal 8.5 14.0 216 356 612 1008
letter 8.5 11.0 216 279 612 792
lettersmall 8.5 11.0 216 279 612 792
archE 36.0 48.0 914 1219 2592 3456
archD 24.0 36.0 610 914 1728 2592
archC 18.0 24.0 457 610 1296 1728
archB 12.0 18.0 305 457 864 1296
archA 9.0 12.0 229 305 648 864"

        sizesISO="\
a0 33.1 46.8 841 1189 2384 3370
a1 23.4 33.1 594 841 1684 2384
a2 16.5 23.4 420 594 1191 1684
a3 11.7 16.5 297 420 842 1191
a4 8.3 11.7 210 297 595 842
a4small 8.3 11.7 210 297 595 842
a5 5.8 8.3 148 210 420 595
a6 4.1 5.8 105 148 297 420
a7 2.9 4.1 74 105 210 297
a8 2.1 2.9 52 74 148 210
a9 1.5 2.1 37 52 105 148
a10 1.0 1.5 26 37 73 105
isob0 39.4 55.7 1000 1414 2835 4008
isob1 27.8 39.4 707 1000 2004 2835
isob2 19.7 27.8 500 707 1417 2004
isob3 13.9 19.7 353 500 1001 1417
isob4 9.8 13.9 250 353 709 1001
isob5 6.9 9.8 176 250 499 709
isob6 4.9 6.9 125 176 354 499
c0 36.1 51.1 917 1297 2599 3677
c1 25.5 36.1 648 917 1837 2599
c2 18.0 25.5 458 648 1298 1837
c3 12.8 18.0 324 458 918 1298
c4 9.0 12.8 229 324 649 918
c5 6.4 9.0 162 229 459 649
c6 4.5 6.4 114 162 323 459"

        sizesJIS="\
jisb0 NA NA 1030 1456 2920 4127
jisb1 NA NA 728 1030 2064 2920
jisb2 NA NA 515 728 1460 2064
jisb3 NA NA 364 515 1032 1460
jisb4 NA NA 257 364 729 1032
jisb5 NA NA 182 257 516 729
jisb6 NA NA 128 182 363 516"

        sizesOther="\
flsa 8.5 13.0 216 330 612 936
flse 8.5 13.0 216 330 612 936
halfletter 5.5 8.5 140 216 396 612
hagaki 3.9 5.8 100 148 283 420"
        
        sizesAll="\
$sizesUS
$sizesISO
$sizesJIS
$sizesOther"

}

# Gets a paper size in points and sets it to RESIZE_WIDTH and RESIZE_HEIGHT
getGSPaperSize() {
        isEmpty "$sizesall" && getPaperInfo
        while read l; do 
                local cols=($l)
                if [[ "$1" == ${cols[0]} ]]; then
                        RESIZE_WIDTH=${cols[5]}
                        RESIZE_HEIGHT=${cols[6]}
                        return $TRUE
                fi
        done <<< "$sizesAll"
}

# Gets a paper size in points and sets it to RESIZE_WIDTH and RESIZE_HEIGHT
getGSPaperName() {
        local w="$(printf "%.0f" $1)"
        local h="$(printf "%.0f" $2)"
        isEmpty "$sizesall" && getPaperInfo
        # Because US Standard has inverted sizes, I need to scan 2 times
        # instead of just testing if width is bigger than height
        while read l; do 
                local cols=($l)
                if [[ "$w" == ${cols[5]} && "$h" == ${cols[6]} ]]; then
                        printf "%s Portrait" $(uppercase ${cols[0]})
                        return $TRUE
                fi
        done <<< "$sizesAll"
        while read l; do 
                local cols=($l)
                if [[ "$w" == ${cols[6]} && "$h" == ${cols[5]} ]]; then
                        printf "%s Landscape" $(uppercase ${cols[0]})
                        return $TRUE
                fi
        done <<< "$sizesAll"
        return $FALSE
}


# Loads an array with paper names to memory
getPaperNames() {
        paperNames=(a0 a1 a2 a3 a4 a4small a5 a6 a7 a8 a9 a10 isob0 isob1 isob2 isob3 isob4 isob5 isob6 c0 c1 c2 c3 c4 c5 c6 \
11x17 ledger legal letter lettersmall archE archD archC archB archA \
jisb0 jisb1 jisb2 jisb3 jisb4 jisb5 jisb6 \
flsa flse halfletter hagaki)
}

# Prints uppercase paper names to screen (used in help)
printPaperNames() {
        isEmpty "$paperNames" && getPaperNames
        for i in "${!paperNames[@]}"; do 
                [[ $i -eq 0 ]] && echo -n -e ' '
                [[ $i -ne 0 && $((i % 5)) -eq 0 ]] && echo -n -e $'\n '
                ppN="$(uppercase ${paperNames[i]})"
                printf "%-14s" "$ppN"
        done
        echo ""
}

# Returns $TRUE if $! is a valid paper name, $FALSE otherwise
isPaperName() {
        isEmpty "$1" && return $FALSE
        isEmpty "$paperNames" && getPaperNames
        for i in "${paperNames[@]}"; do 
                [[ "$i" = "$1" ]] && return $TRUE
        done
        return $FALSE
}

# Prints all tables with ghostscript paper information
printPaperInfo() {
        printVersion
        echo $'\n'"Valid Ghostscript Paper Sizes accepted"$'\n'
        getPaperInfo
        printPaperTable "ISO STANDARD" "$sizesISO"; echo
        printPaperTable "US STANDARD" "$sizesUS"; echo
        printPaperTable "JIS STANDARD *Aproximated Points" "$sizesJIS"; echo
        printPaperTable "OTHERS" "$sizesOther"; echo
}

# GS paper table helper, prints a full line
printTableLine() {
        echo '+-----------------------------------------------------------------+'
}

# GS paper table helper, prints a line with dividers
printTableDivider() {
        echo '+-----------------+-------+-------+-------+-------+-------+-------+'
}

# GS paper table helper, prints a table header
printTableHeader() {
        echo '| Name            | inchW | inchH |  mm W |  mm H | pts W | pts H |'
}

# GS paper table helper, prints a table title
printTableTitle() {
        printf "| %-64s%s\n" "$1" '|'
}

# GS paper table printer, prints a table for a paper variable
printPaperTable() {
        printTableLine
        printTableTitle "$1"
        printTableLine
        printTableHeader
        printTableDivider
        while read l; do 
                local cols=($l)
                printf "| %-15s | %+5s | %+5s | %+5s | %+5s | %+5s | %+5s |\n" ${cols[*]}; 
        done <<< "$2"
        printTableDivider
}

# Validades the a paper resize CLI option and sets the paper to $RESIZE_PAPER_TYPE
parsePaperResize() {
        isEmpty "$1" && initError 'Invalid Paper Type: (empty)' $EXIT_INVALID_PAPER_SIZE
        local lowercasePaper="$(lowercase $1)"
        if [[ "$1" = 'custom' ]]; then
                if isNotValidMeasure "$2" || ! isFloatBiggerThanZero "$3" || ! isFloatBiggerThanZero "$4"; then
                        initError "Invalid Custom Paper Definition!"$'\n'"Use: -r 'custom <measurement> <width> <height>'"$'\n'"Measurements: mm, in, pts" $EXIT_INVALID_OPTION
                fi
                RESIZE_PAPER_TYPE="custom"
                CUSTOM_RESIZE_PAPER=$TRUE
                if isMilimeter "$2"; then
                        RESIZE_WIDTH="$(milimetersToPoints "$3")"
                        RESIZE_HEIGHT="$(milimetersToPoints "$4")"
                elif isInch "$2"; then
                        RESIZE_WIDTH="$(inchesToPoints "$3")"
                        RESIZE_HEIGHT="$(inchesToPoints "$4")"
                elif isPoint "$2"; then
                        RESIZE_WIDTH="$3"
                        RESIZE_HEIGHT="$4"
                else
                        initError "Invalid Custom Paper Definition!"$'\n'"Use: -r 'custom <measurement> <width> <height>'"$'\n'"Measurements: mm, in, pts" $EXIT_INVALID_OPTION
                fi
        else
                isPaperName "$lowercasePaper" || initError "Invalid Paper Type: $1" $EXIT_INVALID_PAPER_SIZE
                RESIZE_PAPER_TYPE="$lowercasePaper"
        fi
}

# Returns $TRUE if $1 is a valid measurement for a custom paper, $FALSE otherwise
isNotValidMeasure() {
        isMilimeter "$1" || isInch "$1" || isPoint "$1" && return $FALSE
        return $TRUE
}

# Returns $TRUE if $1 is a valid milimeter string, $FALSE otherwise
isMilimeter() {
        [[ "$1" = 'mm' || "$1" = 'milimeters' || "$1" = 'milimeter' ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $1 is a valid inch string, $FALSE otherwise
isInch() {
        [[ "$1" = 'in' || "$1" = 'inch' || "$1" = 'inches' ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $1 is a valid point string, $FALSE otherwise
isPoint() {
        [[ "$1" = 'pt' || "$1" = 'pts' || "$1" = 'point' || "$1" = 'points' ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if a custom paper is being used, $FALSE otherwise
isCustomPaper() {
        return $CUSTOM_RESIZE_PAPER
}

isNotCustomPaper() {
        isCustomPaper && return $FALSE
        return $TRUE
}

# Returns $TRUE if the scale was set manually, $FALSE if we are using automatic scaling
isManualScaledMode() {
        [[ $AUTOMATIC_SCALING -eq $TRUE ]] && return $FALSE
        return $TRUE
}

# Returns true if we are resizing a paper (ignores scaling), false otherwise
isResizeMode() {
        isEmpty $RESIZE_PAPER_TYPE && return $FALSE
        return $TRUE
}

# Returns true if we are resizing a paper and the scale was manually set
isMixedMode() {
        isResizeMode && isManualScaledMode && return $TRUE
        return $FALSE
}

# Prints the lowercase char value for $1
lowercaseChar() {
    case "$1" in
        [A-Z])
        n=$(printf "%d" "'$1")
        n=$((n+32))
        printf \\$(printf "%o" "$n")
        ;;
           *)
        printf "%s" "$1"
        ;;
    esac
}

# Prints the lowercase version of a string
lowercase() {
        word="$@"
        for((i=0;i<${#word};i++))
        do
            ch="${word:$i:1}"
            lowercaseChar "$ch"
        done
}

# Prints the uppercase char value for $1
uppercaseChar(){
    case "$1" in
        [a-z])
        n=$(printf "%d" "'$1")
        n=$((n-32))
        printf \\$(printf "%o" "$n")
        ;;
           *)
        printf "%s" "$1"
        ;;
    esac
}

# Prints the uppercase version of a string
uppercase() {
        word="$@"
        for((i=0;i<${#word};i++))
        do
            ch="${word:$i:1}"
            uppercaseChar "$ch"
        done
}

# Prints the postscript points rounded equivalent from $1 mm
milimetersToPoints() {
        local pts=$(echo "scale=8; $1 * 72 / 25.4" | "$BCBIN")
        printf '%.0f' "$pts"    # Print rounded conversion
}

# Prints the postscript points rounded equivalent from $1 inches
inchesToPoints() {
        local pts=$(echo "scale=8; $1 * 72" | "$BCBIN")
        printf '%.0f' "$pts"    # Print rounded conversion
}

# Prints the mm equivalent from $1 postscript points
pointsToMilimeters() {
        local pts=$(echo "scale=8; $1 / 72 * 25.4" | "$BCBIN")
        printf '%.0f' "$pts"    # Print rounded conversion
}

# Prints the inches equivalent from $1 postscript points
pointsToInches() {
        local pts=$(echo "scale=8; $1 / 72" | "$BCBIN")
        printf '%.1f' "$pts"    # Print rounded conversion
}


########################## VALIDATORS ##########################

# Returns $TRUE if $PGWIDTH OR $PGWIDTH are empty or NOT an Integer, $FALSE otherwise
pageSizeIsInvalid() {
        if isNotAnInteger "$PGWIDTH" || isNotAnInteger "$PGHEIGHT"; then
                return $TRUE
        fi
        return $FALSE
}


# Return $TRUE if adaptive mode is enabled, $FALSE otherwise
isAdaptiveMode() {
        return $ADAPTIVEMODE
}


# Return $TRUE if adaptive mode is disabled, $FALSE otherwise
isNotAdaptiveMode() {
        isAdaptiveMode && return $FALSE
        return $TRUE
}


# Return $TRUE if $1 is empty, $FALSE otherwise
isEmpty() {
        [[ -z "$1" ]] && return $TRUE
        return $FALSE
}


# Return $TRUE if $1 is NOT empty, $FALSE otherwise
isNotEmpty() {
        [[ -z "$1" ]] && return $FALSE
        return $TRUE
}

# Returns $TRUE if $1 is an integer, $FALSE otherwise
isAnInteger() {
        case $1 in
            ''|*[!0-9]*) return $FALSE ;;
            *) return $TRUE ;;
        esac
}

# Returns $TRUE if $1 is NOT an integer, $FALSE otherwise
isNotAnInteger() {
        case $1 in
            ''|*[!0-9]*) return $TRUE ;;
            *) return $FALSE ;;
        esac
}

# Returns $TRUE if $1 is a floating point number (or an integer), $FALSE otherwise
isFloat() {
        [[ -n "$1" && "$1" =~ ^-?[0-9]*([.][0-9]+)?$ ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $1 is a floating point number bigger than zero, $FALSE otherwise
isFloatBiggerThanZero() {
        isFloat "$1" && [[ (( $1 > 0 )) ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $1 has a .pdf extension, false otherwsie
isPDF() {
        [[ "$1" =~ ^..*\.pdf$ ]] && return $TRUE
        return $FALSE
}


# Returns $TRUE if $1 is a file, false otherwsie
isFile() {
        [[ -f "$1" ]] && return $TRUE
        return $FALSE
}


# Returns $TRUE if $1 is NOT a file, false otherwsie
notIsFile() {
        [[ -f "$1" ]] && return $FALSE
        return $TRUE
}


# Returns $TRUE if $1 is executable, false otherwsie
isExecutable() {
        [[ -x "$1" ]] && return $TRUE
        return $FALSE
}


# Returns $TRUE if $1 is NOT executable, false otherwsie
notIsExecutable() {
        [[ -x "$1" ]] && return $FALSE
        return $TRUE
}


# Returns $TRUE if $1 is a file and executable, false otherwsie
isAvailable() {
        if isFile "$1" && isExecutable "$1"; then 
                return $TRUE
        fi
        return $FALSE
}


# Returns $TRUE if $1 is NOT a file or NOT executable, false otherwsie
notIsAvailable() {
        if notIsFile "$1" || notIsExecutable "$1"; then 
                return $TRUE
        fi
        return $FALSE
}


###################### PRINTING TO SCREEN ######################

# Prints version
printVersion() {
        local vStr=""
        [[ "$2" = 'verbose' ]] && vStr=" - Verbose Execution"
        local strBanner="$PDFSCALE_NAME v$VERSION$vStr"
        if [[ $1 -eq 2 ]]; then
                printError "$strBanner"
        elif [[ $1 -eq 3 ]]; then
                local extra="$(isNotEmpty "$2" && echo "$2")"
                echo "$strBanner$extra"
        else
                vprint "$strBanner"
        fi
}

# Prints the scale factor to screen, or custom message
vPrintScaleFactor() {
        local scaleMsg="$SCALE"
        isNotEmpty "$1" && scaleMsg="$1"
        vprint "  Scale Factor: $scaleMsg"
}


# Prints help info
printHelp() {
        printVersion 3
        local paperList="$(printPaperNames)"
        echo "
Usage: $PDFSCALE_NAME <inFile.pdf>
       $PDFSCALE_NAME -i <inFile.pdf>
       $PDFSCALE_NAME [-v] [-s <factor>] [-m <page-detection>] <inFile.pdf> [outfile.pdf]
       $PDFSCALE_NAME [-v] [-r <paper>] [-f <flip-detection>] [-a <auto-rotation>] <inFile.pdf> [outfile.pdf]
       $PDFSCALE_NAME -p
       $PDFSCALE_NAME -h
       $PDFSCALE_NAME -V

Parameters:
 -v          Verbose mode, prints extra information
             Use twice for timestamp
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
 -m <mode>   Page size Detection mode 
             May disable the Adaptive Mode
 -i <file>   Prints <file> Page Size information to screen and exits
 -s <factor> Changes the scaling factor or forces scaling
             Defaults: $SCALE / no scaling (resize mode)
             MUST be a number bigger than zero
             Eg. -s 0.8 for 80% of the original size
 -r <paper>  Triggers the Resize Paper Mode
             Resize PDF paper proportionally
             Uses a valid paper name or a custom defined paper
 -f <mode>   Flip Detection Mode, defaults to 'auto'.
             Inverts Width <-> Height of a Resized PDF.
             Modes: a, auto    - automatic detection, default
                    f, force   - forces flip W <-> H
                    d, disable - disables flipping 
 -a <mode>   GS Auto-Rotation Setting, defaults to 'PageByPage'.
             Setting for GS -dAutoRotatePages.
             Modes: p, pagebypage - auto-rotates pages individually
                    a, all        - rotates all pages (or none) depending
                                    on a kind of \"majority decision\"
                    n, none       - retains orientation of each page
 -p          Prints Ghostscript paper info tables to screen

Scaling Mode:
 The default mode of operation is scaling mode with fixed paper
 size and scaling pre-set to $SCALE. By not using the resize mode
 you are using scaling mode. Flip-Detection and Auto-Rotation are
 disabled in Scaling mode.

Resize Paper Mode:
 Disables the default scaling factor! ($SCALE)
 Changes the PDF Paper Size in points. Will fit-to-page.

Mixed Mode:
 In mixed mode both the -s option and -r option must be specified.
 The PDF will be first resized then scaled.

Output filename:
 The output filename is optional. If no file name is passed
 the output file will have the same name/destination of the
 input file with added suffixes:
   .SCALED.pdf             is added to scaled files
   .<PAPERSIZE>.pdf        is added to resized files
   .<PAPERSIZE>.SCALED.pdf is added in mixed mode

Page Size Detection Modes:
 a, adaptive  Default mode, tries all the methods below
 g, grep      Forces the use of grep method
 m, mdls      Forces the use of MacOS Quartz mdls
 p, pdfinfo   Forces the use of PDFInfo
 i, identify  Forces the use of ImageMagick's Identify

Valid Paper Names: (case-insensitive)
$paperList

Custom Paper Size:
 Paper size can be set manually in Milimeters, Inches or Points.
 Use: $PDFSCALE_NAME -r 'custom <measurement> <width> <height>'
 Ex:  $PDFSCALE_NAME -r 'custom mm 300 300'
 Measurements can be: mm, inch, pts.
 Custom paper definition MUST be quoted into a single parameter.
 Actual size is applied in points (mms and inches are transformed).

Additional Notes:
 - Adaptive Page size detection will try different modes until
   it gets a page size. You can force a mode with -m 'mode'.
 - Options must be passed before the file names to be parsed.
 - Having the extension .pdf on the output file name is optional,
   it will be added if not present.
 - File and folder names with spaces should be quoted or escaped.
 - The scaling is centered and using a scale bigger than 1 may
   result on cropping parts of the pdf.
 - Most of the options are case-insensitive, Ex: -m PdFinFo

Examples:
 $PDFSCALE_NAME myPdfFile.pdf
 $PDFSCALE_NAME -i '/home/My Folder/My PDF File.pdf'
 $PDFSCALE_NAME myPdfFile.pdf \"My Scaled Pdf\"
 $PDFSCALE_NAME -v -v myPdfFile.pdf
 $PDFSCALE_NAME -s 0.85 myPdfFile.pdf My\\ Scaled\\ Pdf.pdf
 $PDFSCALE_NAME -m pdfinfo -s 0.80 -v myPdfFile.pdf
 $PDFSCALE_NAME -v -v -m i -s 0.7 myPdfFile.pdf
 $PDFSCALE_NAME -r A4 myPdfFile.pdf
 $PDFSCALE_NAME -v -v -r \"custom mm 252 356\" -s 0.9 -f \"../input file.pdf\" \"../my new pdf\"
"
}


# Prints usage info
usage() { 
        [[ "$2" != 'nobanner' ]] && printVersion 2
        isNotEmpty "$1" && printError "$1"
        printError "Usage: $PDFSCALE_NAME [-v] [-s <factor>] [-m <mode>] <inFile.pdf> [outfile.pdf]"
        printError "Try:   $PDFSCALE_NAME -h # for help"
}


# Prints Verbose information
vprint() {
        [[ $VERBOSE -eq 0 ]] && return $TRUE
        timestamp=""
        [[ $VERBOSE -gt 1 ]] && timestamp="$(date +%Y-%m-%d:%H:%M:%S) | "
        echo "$timestamp$1"
}


# Prints dependency information and aborts execution
printDependency() {
        #printVersion 2
        local brewName="$1"
        [[ "$1" = 'pdfinfo' && "$OSNAME" = "Darwin" ]] && brewName="xpdf"
        printError $'\n'"ERROR! You need to install the package '$1'"$'\n'
        printError "Linux apt-get.: sudo apt-get install $1"
        printError "Linux yum.....: sudo yum install $1"
        printError "MacOS homebrew: brew install $brewName"
        printError $'\n'"Aborting..."
        exit $EXIT_MISSING_DEPENDENCY
}


# Prints initialization errors and aborts execution
initError() {
        local errStr="$1"
        local exitStat=$2
        isEmpty "$exitStat" && exitStat=$EXIT_ERROR
        usage "ERROR! $errStr" "$3"
        exit $exitStat
}


# Prints to stderr
printError() {
        echo >&2 "$@"
}




########################## EXECUTION ###########################

initDeps
getOptions "${@}"
main
exit $?

