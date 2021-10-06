#!/usr/bin/env bash

################################################################
#
# pdfScale.sh
#
# Manipulate PDFs using Ghostscript.
# Scale, Resize and Split PDFs.
# Writen for Bash.
#
# Gustavo Arnosti Neves - 2016 / 07 / 10
#        Latest Version - 2020 / 04 / 04
#
# This app: https://github.com/tavinus/pdfScale
#
# THIS SOFTWARE IS FREE - HAVE FUN WITH IT
# I hope this can be of help to people. Thanks to the people
# that helped and donated. It has been a long run with this
# script. I wish you all the best! -]
#
################################################################

VERSION="2.5.4"


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
GS_RUN_STATUS=""               # Holds GS error messages, signals errors

INFILEPDF=""                # Input PDF file name
OUTFILEPDF=""               # Output PDF file name
JUST_IDENTIFY=$FALSE        # Flag to just show PDF info
ABORT_ON_OVERWRITE=$FALSE   # Flag to abort if OUTFILEPDF already exists
ADAPTIVEMODE=$TRUE          # Automatically try to guess best mode
AUTOMATIC_SCALING=$TRUE     # Default scaling in $SCALE, disabled in resize mode
MODE=""                     # Which page size detection to use
RESIZE_PAPER_TYPE=""        # Pre-defined paper to use
CUSTOM_RESIZE_PAPER=$FALSE  # If we are using a custom-defined paper
CROPBOX_PAPER_TYPE=""       # Pre-defined paper to use for cropboxes
CUSTOM_CROPBOX_PAPER=$FALSE # If we are using a custom-defined cropbox
FLIP_DETECTION=$TRUE        # If we should run the Flip-detection
FLIP_FORCE=$FALSE           # If we should force Flipping
AUTO_ROTATION='/PageByPage' # GS call auto-rotation setting
FIT_PAGE='-dPDFFitPage'     # GS call resize fit page setting
DPRINTED=""                 # Print to screen or printer ? -dPrinted=false
PGWIDTH=""                  # Input PDF Page Width
PGHEIGHT=""                 # Input PDF Page Height
RESIZE_WIDTH=""             # Resized PDF Page Width
RESIZE_HEIGHT=""            # Resized PDF Page Height

############################# Image resolution (dpi) 
IMAGE_RESOLUTION=300        # 300 is /Printer default

############################# Image compression setting
#                             default        screen        ebook        printer        prepress 
# ColorImageDownsampleType    /Subsample     /Average      /Bicubic     /Bicubic       /Bicubic 
IMAGE_DOWNSAMPLE_TYPE='/Bicubic'

############################# default PDF profile
# /screen /ebook /printer /prepress /default
# -dPDFSETTINGS=/screen   (screen-view-only quality, 72 dpi images)
# -dPDFSETTINGS=/ebook    (low quality, 150 dpi images)
# -dPDFSETTINGS=/printer  (high quality, 300 dpi images)
# -dPDFSETTINGS=/prepress (high quality, color preserving, 300 dpi imgs)
# -dPDFSETTINGS=/default  (almost identical to /screen)
PDF_SETTINGS='/printer'

############################# default Scaling alignment
VERT_ALIGN="CENTER"
HOR_ALIGN="CENTER"

############################# Translation Offset to apply
XTRANSOFFSET=0.0
YTRANSOFFSET=0.0

############################# Background/Bleed color creation
BACKGROUNDTYPE="NONE"       # Should be NONE, CMYK or RGB only
BACKGROUNDCOLOR=""          # Color parameters for CMYK(4) or RGB(3)
BACKGROUNDCALL=""           # Actual PS call to be embedded
BACKGROUNDLOG="No background (default)"

############################# Execution Flags
SIMULATE=$FALSE             # Avoid execution
PRINT_GS_CALL=$FALSE        # Print GS Call to stdout
GS_CALL_STRING=""           # Buffer
RESIZECOMMANDS=""           # command to run on resize call

############################# Project Info
PROJECT_NAME="pdfScale"
PROJECT_URL="https://github.com/tavinus/$PROJECT_NAME"
PROJECT_BRANCH='master'
HTTPS_INSECURE=$FALSE
ASSUME_YES=$FALSE
RUN_SELF_INSTALL=$FALSE
TARGET_LOC="/usr/local/bin/pdfscale"

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
EXIT_NOWRITE_PERMISSION=29
EXIT_NOREAD_PERMISSION=30
EXIT_TEMP_FILE_EXISTS=40
EXIT_INVALID_PAPER_SIZE=50
EXIT_INVALID_IMAGE_RESOLUTION=51


############################# MAIN #############################

# Main function called at the end
main() {
        printPDFSizes  # may exit here
        local finalRet=$EXIT_ERROR

        if isMixedMode; then
                initMain "   Mixed Tasks: Resize & Scale"
                local tempFile=""
                local tempSuffix="$RANDOM$RANDOM""_TEMP_$RANDOM$RANDOM.pdf"
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
                if isFile "$tempFile"; then
                        rm "$tempFile" >/dev/null 2>&1 || printError "Error when removing temporary file: $tempFile"
                fi
        elif isResizeMode; then
                initMain "   Single Task: Resize PDF Paper"
                vPrintScaleFactor "Disabled (resize only)"
                pageResize
                finalRet=$?
        else
                initMain "   Single Task: Scale PDF Contents"
                local scaleMode=""
                isManualScaledMode && scaleMode='(manual)' || scaleMode='(auto)'
                vPrintScaleFactor "$SCALE $scaleMode"
                pageScale
                finalRet=$?
        fi

        if [[ $finalRet -eq $EXIT_SUCCESS ]] && isEmpty "$GS_RUN_STATUS"; then
                if isDryRun; then
                        vprint "  Final Status: Simulation completed successfully"
                else
                        vprint "  Final Status: File created successfully"
                fi
        else
                vprint "  Final Status: Error detected. Exit status: $finalRet"
                printError "PdfScale: ERROR!"$'\n'"Ghostscript Debug Info:"$'\n'"$GS_RUN_STATUS"
        fi
        
        if isNotEmpty "$GS_CALL_STRING" && shouldPrintGSCall; then
                printf "%s" "$GS_CALL_STRING"
        fi

        return $finalRet
}

# Initializes PDF processing for all modes of operation
initMain() {
        printVersion 1 'verbose'
        isNotEmpty "$1" && vprint "$1"
        local sim="FALSE"
        isDryRun && sim="TRUE (Simulating)"
        vprint "       Dry-Run: $sim"
        vPrintFileInfo
        getPageSize
        vPrintPageSizes ' Source'
	vShowPrintMode
}

# Prints PDF Info and exits with $EXIT_SUCCESS, but only if $JUST_IDENTIFY is $TRUE
printPDFSizes() {
        if [[ $JUST_IDENTIFY -eq $TRUE ]]; then
                VERBOSE=0
                printVersion 3 " - Paper Sizes"
                getPageSize || initError "Could not get pagesize!"
                local paperType="$(getGSPaperName $PGWIDTH $PGHEIGHT)"
                isEmpty "$paperType" && paperType="Custom Paper Size"
                printf '%s\n' "------------+-----------------------------"
                printf "       File | %s\n" "$(basename "$INFILEPDF")"
                printf " Paper Type | %s\n" "$paperType"
                printf '%s\n' "------------+-----------------------------"
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
        # Compute translation factors to position pages
        CENTERXTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGWIDTH" | "$BCBIN")
        CENTERYTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGHEIGHT" | "$BCBIN")
        BXTRANS=$CENTERXTRANS
        BYTRANS=$CENTERYTRANS
        if [[ "$VERT_ALIGN" = "TOP" ]]; then
            BYTRANS=$(echo "scale=6; 2*$CENTERYTRANS" | "$BCBIN")
        elif [[ "$VERT_ALIGN" = "BOTTOM" ]]; then
            BYTRANS=0
        fi
        if [[ "$HOR_ALIGN" = "LEFT" ]]; then
            BXTRANS=0
        elif [[ "$HOR_ALIGN" = "RIGHT" ]]; then
            BXTRANS=$(echo "scale=6; 2*$CENTERXTRANS" | "$BCBIN")
        fi
        vprint "    Vert-Align: $VERT_ALIGN"
        vprint "     Hor-Align: $HOR_ALIGN"

        XTRANS=$(echo "scale=6; $BXTRANS + $XTRANSOFFSET" | "$BCBIN")
        YTRANS=$(echo "scale=6; $BYTRANS + $YTRANSOFFSET" | "$BCBIN")

        vprint "$(printf ' Translation X: %.2f = %.2f + %.2f (offset)' $XTRANS $BXTRANS $XTRANSOFFSET)"
        vprint "$(printf ' Translation Y: %.2f = %.2f + %.2f (offset)' $YTRANS $BYTRANS $YTRANSOFFSET)"

        local increase=$(echo "scale=0; (($SCALE - 1) * 100)/1" | "$BCBIN")
        vprint "   Run Scaling: $increase %"
        
        vprint "    Background: $BACKGROUNDLOG"

        GS_RUN_STATUS="$GS_RUN_STATUS""$(gsPageScale 2>&1)"
        GS_CALL_STRING="$GS_CALL_STRING"$'[GS SCALE CALL STARTS]\n'"$(gsPrintPageScale)"$'\n[GS SCALE CALL ENDS]\n'
        return $? # Last command is always returned I think
}

# Runs GS call for scaling, nothing else should run here
gsPageScale() {
        if isDryRun; then
                return $TRUE
        fi
        # Scale page
        "$GSBIN" \
-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dSAFER \
-dCompatibilityLevel="1.5" -dPDFSETTINGS="$PDF_SETTINGS" \
-dColorImageResolution=$IMAGE_RESOLUTION -dGrayImageResolution=$IMAGE_RESOLUTION \
-dColorImageDownsampleType="$IMAGE_DOWNSAMPLE_TYPE" -dGrayImageDownsampleType="$IMAGE_DOWNSAMPLE_TYPE" \
-dColorConversionStrategy=/LeaveColorUnchanged \
-dSubsetFonts=true -dEmbedAllFonts=true \
-dDEVICEWIDTHPOINTS=$PGWIDTH -dDEVICEHEIGHTPOINTS=$PGHEIGHT \
$DPRINTED \
-sOutputFile="$OUTFILEPDF" \
-c "<</BeginPage{$BACKGROUNDCALL$SCALE $SCALE scale $XTRANS $YTRANS translate}>> setpagedevice" \
-f "$INFILEPDF" 
        
}

# Prints GS call for scaling
gsPrintPageScale() {
        local _call_str=""
        # Print Scale page command
        read -d '' _call_str<< _EOF_
        "$GSBIN" \
-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dSAFER \
-dCompatibilityLevel="1.5" -dPDFSETTINGS="$PDF_SETTINGS" \
-dColorImageResolution=$IMAGE_RESOLUTION -dGrayImageResolution=$IMAGE_RESOLUTION \
-dColorImageDownsampleType="$IMAGE_DOWNSAMPLE_TYPE" -dGrayImageDownsampleType="$IMAGE_DOWNSAMPLE_TYPE" \
-dColorConversionStrategy=/LeaveColorUnchanged \
-dSubsetFonts=true -dEmbedAllFonts=true \
-dDEVICEWIDTHPOINTS=$PGWIDTH -dDEVICEHEIGHTPOINTS=$PGHEIGHT \
$DPRINTED \
-sOutputFile="$OUTFILEPDF" \
-c "<</BeginPage{$BACKGROUNDCALL$SCALE $SCALE scale $XTRANS $YTRANS translate}>> setpagedevice" \
-f "$INFILEPDF"
_EOF_

        echo -ne "$_call_str"
}

# Runs the ghostscript paper resize script
pageResize() {
        # Get paper sizes from source if not resizing
        isResizePaperSource && { RESIZE_WIDTH=$PGWIDTH; RESIZE_HEIGHT=$PGHEIGHT; }
        # Get new paper sizes if not custom or source paper
        isNotCustomPaper && ! isResizePaperSource && getGSPaperSize "$RESIZE_PAPER_TYPE"
		local fpStatus="Enabled (default)"
		isEmpty $FIT_PAGE && fpStatus="Disabled (manual)"
        vprint "   Fit To Page: $fpStatus"
        vprint "   Auto Rotate: $(basename $AUTO_ROTATION)"
        runFlipDetect
        vprint "  Run Resizing: $(uppercase "$RESIZE_PAPER_TYPE") ( "$RESIZE_WIDTH" x "$RESIZE_HEIGHT" ) pts"
        if shouldSetCropbox; then
                if [[ $CROPBOX_PAPER_TYPE == 'fullsize' ]]; then
                        CROPBOX_WIDTH=$RESIZE_WIDTH
                        CROPBOX_HEIGHT=$RESIZE_HEIGHT
                elif [[ $CROPBOX_PAPER_TYPE != 'custom' ]]; then
                        getCropboxPaperSize "$CROPBOX_PAPER_TYPE"
                fi
                RESIZECOMMANDS='<</EndPage {0 eq {[/CropBox [0 0 '"$CROPBOX_WIDTH $CROPBOX_HEIGHT"'] /PAGE pdfmark true}{false}ifelse}>> setpagedevice'
                vprint " Cropbox Reset: $(uppercase "$CROPBOX_PAPER_TYPE") ( "$CROPBOX_WIDTH" x "$CROPBOX_HEIGHT" ) pts"
        fi
        GS_RUN_STATUS="$GS_RUN_STATUS""$(gsPageResize 2>&1)"
        GS_CALL_STRING="$GS_CALL_STRING"$'[GS RESIZE CALL STARTS]\n'"$(gsPrintPageResize)"$'\n[GS RESIZE CALL ENDS]\n'
        return $?
}

# Runs GS call for resizing, nothing else should run here
gsPageResize() {
        if isDryRun; then
                return $TRUE
        fi

        # Change page size
        "$GSBIN" \
-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dSAFER \
-dCompatibilityLevel="1.5" -dPDFSETTINGS="$PDF_SETTINGS" \
-dColorImageResolution=$IMAGE_RESOLUTION -dGrayImageResolution=$IMAGE_RESOLUTION \
-dColorImageDownsampleType="$IMAGE_DOWNSAMPLE_TYPE" -dGrayImageDownsampleType="$IMAGE_DOWNSAMPLE_TYPE" \
-dColorConversionStrategy=/LeaveColorUnchanged \
-dSubsetFonts=true -dEmbedAllFonts=true \
-dDEVICEWIDTHPOINTS=$RESIZE_WIDTH -dDEVICEHEIGHTPOINTS=$RESIZE_HEIGHT \
-dAutoRotatePages=$AUTO_ROTATION \
-dFIXEDMEDIA $FIT_PAGE $DPRINTED \
-sOutputFile="$OUTFILEPDF" -c "$RESIZECOMMANDS" \
-f "$INFILEPDF"
        return $?
}

# Prints GS call for resizing
gsPrintPageResize() {
        # Print Resize page command
        local _call_str=""
        # Print Scale page command
        read -d '' _call_str<< _EOF_
"$GSBIN" \
-q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dSAFER \
-dCompatibilityLevel="1.5" -dPDFSETTINGS="$PDF_SETTINGS" \
-dColorImageResolution=$IMAGE_RESOLUTION -dGrayImageResolution=$IMAGE_RESOLUTION \
-dColorImageDownsampleType="$IMAGE_DOWNSAMPLE_TYPE" -dGrayImageDownsampleType="$IMAGE_DOWNSAMPLE_TYPE" \
-dColorConversionStrategy=/LeaveColorUnchanged \
-dSubsetFonts=true -dEmbedAllFonts=true \
-dDEVICEWIDTHPOINTS=$RESIZE_WIDTH -dDEVICEHEIGHTPOINTS=$RESIZE_HEIGHT \
-dAutoRotatePages=$AUTO_ROTATION \
-dFIXEDMEDIA $FIT_PAGE $DPRINTED \
-sOutputFile="$OUTFILEPDF" -c "$RESIZECOMMANDS" \
-f "$INFILEPDF"
_EOF_

        echo -ne "$_call_str"
}

# Returns $TRUE if we should use the source paper size, $FALSE otherwise
isResizePaperSource() {
        [[ "$RESIZE_PAPER_TYPE" = 'source' ]] && return $TRUE
        return $FALSE
}

# Filp-Detect Logic
runFlipDetect() {
        if isFlipForced; then
                vprint "   Flip Detect: Forced Mode!"
                applyFlipRevert
        elif isFlipDetectionEnabled && shouldFlip; then
                vprint "   Flip Detect: Wrong orientation detected!"
                applyFlipRevert
        elif ! isFlipDetectionEnabled; then
                vprint "   Flip Detect: Disabled"
        else
                vprint "   Flip Detect: No change needed"
        fi
}

# Inverts $RESIZE_HEIGHT with $RESIZE_WIDTH
applyFlipRevert() {
        local tmpInverter=""
        tmpInverter=$RESIZE_HEIGHT
        RESIZE_HEIGHT=$RESIZE_WIDTH
        RESIZE_WIDTH=$tmpInverter
        vprint "                Inverting Width <-> Height"
}

# Returns the $FLIP_DETECTION flag
isFlipDetectionEnabled() {
        return $FLIP_DETECTION
}

# Returns the $FLIP_FORCE flag
isFlipForced() {
        return $FLIP_FORCE
}

# Returns $TRUE if the the paper size will invert orientation from source, $FALSE otherwise
shouldFlip() {
        [[ $PGWIDTH -gt $PGHEIGHT && $RESIZE_WIDTH -lt $RESIZE_HEIGHT ]] || [[ $PGWIDTH -lt $PGHEIGHT && $RESIZE_WIDTH -gt $RESIZE_HEIGHT ]] && return $TRUE
        return $FALSE
}


########################## INITIALIZERS #########################

# Loads external dependencies and checks for errors
initDeps() {
        GREPBIN="$(command -v grep 2>/dev/null)"
        GSBIN="$(command -v gs 2>/dev/null)"
        BCBIN="$(command -v bc 2>/dev/null)"
        IDBIN=$(command -v identify 2>/dev/null)
        MDLSBIN="$(command -v mdls 2>/dev/null)"
        PDFINFOBIN="$(command -v pdfinfo 2>/dev/null)"
        
        vprint "Checking for basename, grep, ghostscript and bcmath"
        basename "" >/dev/null 2>&1 || printDependency 'basename'
        isNotAvailable "$GREPBIN" && printDependency 'grep'
        isNotAvailable "$GSBIN" && printDependency 'ghostscript'
        isNotAvailable "$BCBIN" && printDependency 'bc'
        return $TRUE
}

# Checks for dependencies errors, run after getting options
checkDeps() {
        if [[ $MODE = "IDENTIFY" ]]; then
                vprint "Checking for imagemagick's identify"
                if isNotAvailable "$IDBIN"; then printDependency 'imagemagick'; fi
        fi
        if [[ $MODE = "PDFINFO" ]]; then
                vprint "Checking for pdfinfo"
                if isNotAvailable "$PDFINFOBIN"; then printDependency 'pdfinfo'; fi
        fi
        if [[ $MODE = "MDLS" ]]; then
                vprint "Checking for MacOS mdls"
                if isNotAvailable "$MDLSBIN"; then 
                        initError 'mdls executable was not found! Is this even MacOS?' $EXIT_MAC_MDLS_NOT_FOUND
                fi
        fi
        return $TRUE
}


######################### CLI OPTIONS ##########################

# Parse options
getOptions() {
        local _optArgs=()    # things that do not start with a '-'
        local _tgtFile=""    # to set $OUTFILEPDF
        local _currParam=""  # to enable case-insensitiveness
        while [ ${#} -gt 0 ]; do
                if [[ "${1:0:2}" = '--' ]]; then
                        # Long Option, get lowercase version
                        _currParam="$(lowercase ${1})"
                elif [[ "${1:0:1}" = '-' ]]; then
                        # short Option, just assign
                        _currParam="${1}"
                else
                        # file name arguments, store as is and reset loop
                        _optArgs+=("$1")
                        shift
                        continue
                fi 
                case "$_currParam" in
                -v|--verbose)
                        ((VERBOSE++))
                        shift
                        ;;
                -n|--no-overwrite|--nooverwrite)
                        ABORT_ON_OVERWRITE=$TRUE
                        shift
                        ;;
                -h|--help)
                        printHelp
                        exit $EXIT_SUCCESS
                        ;;
                -V|--version)
                        printVersion 3
                        exit $EXIT_SUCCESS
                        ;;
                -i|--identify|--info)
                        JUST_IDENTIFY=$TRUE
                        shift
                        ;;
                -s|--scale|--setscale|--set-scale)
                        shift
                        parseScale "$1"
                        shift
                        ;;
                -m|--mode|--paperdetect|--paper-detect|--pagesizemode|--page-size-mode)
                        shift
                        parseMode "$1"
                        shift
                        ;;
                -r|--resize)
                        shift
                        parsePaperResize "$1"
                        shift
                        ;;
                -c|--cropbox)
                        shift
                        parseCropbox "$1"
                        shift
                        ;;
                -p|--printpapers|--print-papers|--listpapers|--list-papers)
                        printPaperInfo
                        exit $EXIT_SUCCESS
                        ;;
                -f|--flipdetection|--flip-detection|--flip-mode|--flipmode|--flipdetect|--flip-detect)
                        shift
                        parseFlipDetectionMode "$1"
                        shift
                        ;;
                -a|--autorotation|--auto-rotation|--autorotate|--auto-rotate)
                        shift
                        parseAutoRotationMode "$1"
                        shift
                        ;;
                --printmode|--print-mode)
                        shift
                        parsePrintMode "$1"
                        shift
                        ;;
                --no-fit-page|--no-fit-to-page|--disable-fit-to-page|--disable-fit-page|--nofitpage|--nofittopage|--disablefittopage|--disablefitpage)
			FIT_PAGE=''
                        shift
                        ;;
                --background-gray)
                        shift
                        parseGrayBackground $1
                        shift
                        ;;
                --background-rgb)
                        shift
                        parseRGBBackground $1
                        shift
                        ;;
                --background-cmyk)
                        shift
                        parseCMYKBackground $1
                        shift
                        ;;
                --pdf-settings)
                        shift
                        parsePDFSettings "$1"
                        shift
                        ;;
                --image-downsample)
                        shift
                        parseImageDownSample "$1"
                        shift
                        ;;
                --image-resolution)
                        shift
                        parseImageResolution "$1"
                        shift
                        ;;
                --horizontal-alignment|--hor-align|--xalign|--x-align)
                        shift
                        parseHorizontalAlignment "$1"
                        shift
                        ;;
                --vertical-alignment|--ver-align|--vert-align|--yalign|--y-align)
                        shift
                        parseVerticalAlignment "$1"
                        shift
                        ;;
                --xtrans|--xtrans-offset|--xoffset)
                        shift
                        parseXTransOffset "$1"
                        shift
                        ;;
                --ytrans|--ytrans-offset|--yoffset)
                        shift
                        parseYTransOffset "$1"
                        shift
                        ;;
                --simulate|--dry-run)
                        SIMULATE=$TRUE
                        shift
                        ;;
                --install|--self-install)
                        RUN_SELF_INSTALL=$TRUE
                        shift
                        if [[ ${1:0:1} != "-" ]]; then
                                TARGET_LOC="$1"
                                shift
                        fi
                        ;;
                --upgrade|--self-upgrade)
                        RUN_SELF_UPGRADE=$TRUE
                        shift
                        ;;
                --insecure|--no-check-certificate)
                        HTTPS_INSECURE=$TRUE
                        shift
                        ;;
                --yes|--assume-yes)
                        ASSUME_YES=$TRUE
                        shift
                        ;;
                --print-gs-call|--gs-call)
                        PRINT_GS_CALL=$TRUE
                        shift
                        ;;
                *)
                        initError "Invalid Parameter: \"$1\"" $EXIT_INVALID_OPTION
                        ;;
            esac
        done
        
        shouldInstall && selfInstall "$TARGET_LOC" # WILL EXIT HERE
        shouldUpgrade && selfUpgrade               # WILL EXIT HERE

        isEmpty "${_optArgs[2]}" || initError "Seems like you passed an extra file name?"$'\n'"Invalid option: ${_optArgs[2]}" $EXIT_INVALID_OPTION

        if [[ $JUST_IDENTIFY -eq $TRUE ]]; then
                isEmpty "${_optArgs[1]}" || initError "Seems like you passed an extra file name?"$'\n'"Invalid option: ${_optArgs[1]}" $EXIT_INVALID_OPTION
                VERBOSE=0      # remove verboseness if present
        fi
        
        # Validate input PDF file
        INFILEPDF="${_optArgs[0]}"
        isEmpty "$INFILEPDF"    && initError "Input file is empty!" $EXIT_NO_INPUT_FILE
        isPDF "$INFILEPDF"      || initError "Input file is not a PDF file: $INFILEPDF" $EXIT_INPUT_NOT_PDF
        isFile "$INFILEPDF"     || initError "Input file not found: $INFILEPDF" $EXIT_FILE_NOT_FOUND
        isReadable "$INFILEPDF" || initError "No read access to input file: $INFILEPDF"$'\nPermission Denied' $EXIT_NOREAD_PERMISSION

        checkDeps

        if [[ $JUST_IDENTIFY -eq $TRUE ]]; then
                return $TRUE    # no need to get output file, so return already
        fi

        _tgtFile="${_optArgs[1]}"
        local _autoName="${INFILEPDF%.*}" # remove possible stupid extension, like .pDF
        if isMixedMode; then
                isEmpty "$_tgtFile" && OUTFILEPDF="${_autoName}.$(uppercase $RESIZE_PAPER_TYPE).SCALED.pdf"
        elif isResizeMode; then
                isEmpty "$_tgtFile" && OUTFILEPDF="${_autoName}.$(uppercase $RESIZE_PAPER_TYPE).pdf"
        else
                isEmpty "$_tgtFile" && OUTFILEPDF="${_autoName}.SCALED.pdf"
        fi
        isNotEmpty "$_tgtFile" && OUTFILEPDF="${_tgtFile%.pdf}.pdf"
        validateOutFile 
}

# Returns $TRUE if the install flag is set
shouldInstall() {
        return $RUN_SELF_INSTALL
}

# Returns $TRUE if the upgrade flag is set
shouldUpgrade() {
        return $RUN_SELF_UPGRADE
}

# Install pdfScale
selfInstall() {
        #CURRENT_LOC="$(readlink -f $0)"
        CURRENT_LOC="$(readlinkf $0)"
        TARGET_LOC="$1"
        isEmpty "$TARGET_LOC" && TARGET_LOC="/usr/local/bin/pdfscale"
        VERBOSE=0
        NEED_SUDO=$FALSE
        printVersion 3 " - Self Install"
        echo ""
        echo "Current location : $CURRENT_LOC"
        echo "Target location  : $TARGET_LOC"
        if [[ "$CURRENT_LOC" = "$TARGET_LOC" ]]; then
                echo $'\n'"Error! Source and Target locations are the same!"
                echo "Cannot copy to itself..."
                exit $EXIT_INVALID_OPTION
        fi
        TARGET_FOLDER="$(dirname $TARGET_LOC)"
        local _answer="NO"
        if isNotDir "$TARGET_FOLDER"; then
                echo $'\nThe target folder does not exist\n > '"$TARGET_FOLDER"
                if assumeYes; then
                        echo ''
                        _answer="y"
                else
                        read -p $'\nCreate the target folder? Y/y to continue > ' _answer
                        _answer="$(lowercase $_answer)"
                fi
                if [[ "$_answer" = "y" || "$_answer" = "yes" ]]; then
                        _answer="no"
                        if mkdir -p "$TARGET_FOLDER" 2>/dev/null; then
                                echo " > Folder Created!"
                        else
                                echo $'\n'"There was an error when trying to create the folder."
                                if assumeYes; then
                                        echo $'\nTrying again with sudo, enter password if needed > '
                                        _answer="y"
                                else
                                        read -p $'\nDo you want to try again with sudo (as root)? Y/y to continue > ' _answer
                                        _answer="$(lowercase $_answer)"
                                fi
                                if [[ "$_answer" = "y" || "$_answer" = "yes" ]]; then
                                        NEED_SUDO=$TRUE
                                        if sudo mkdir -p "$TARGET_FOLDER" 2>/dev/null; then
                                                echo "Folder Created!"
                                        else
                                                echo "There was an error when trying to create the folder."
                                                exit $EXIT_ERROR
                                        fi
                                else
                                        echo "Exiting..."
                                        exit $EXIT_ERROR
                                fi
                        fi
                else
                        echo "Exiting... (cancelled by user)"
                        exit $EXIT_ERROR
                fi
        fi
        _answer="no"
        if isFile "$TARGET_LOC"; then
                echo $'\n'"The target file already exists: $TARGET_LOC"
                if assumeYes; then
                        _answer="y"
                else
                        read -p "Y/y to overwrite, anything else to cancel > " _answer
                        _answer="$(lowercase $_answer)"
                fi
                if [[ "$_answer" = "y" || "$_answer" = "yes" ]]; then
                        echo "Target will be replaced!"
                else
                        echo "Exiting... (cancelled by user)"
                        exit $EXIT_ERROR
                fi
        fi
        if [[ $NEED_SUDO -eq $TRUE ]]; then
                if sudo cp "$CURRENT_LOC" "$TARGET_LOC"; then
                        sudo chmod +x "$TARGET_LOC"
                        echo $'\nSuccess! Program installed!'
                        echo " > $TARGET_LOC"
                        exit $EXIT_SUCCESS
                else
                        echo "There was an error when trying to install the program."
                        exit $EXIT_ERROR
                fi
        fi
        if cp "$CURRENT_LOC" "$TARGET_LOC"; then
                chmod +x "$TARGET_LOC"
                echo $'\nSuccess! Program installed!'
                echo " > $TARGET_LOC"
                exit $EXIT_SUCCESS
        else
                _answer="no"
                echo "There was an error when trying to install pdfScale."
                if assumeYes; then
                        echo $'\nTrying again with sudo, enter password if needed > '
                        _answer="y"
                else
                        read -p $'Do you want to try again with sudo (as root)? Y/y to continue > ' _answer
                        _answer="$(lowercase $_answer)"
                fi
                if [[ "$_answer" = "y" || "$_answer" = "yes" ]]; then
                        NEED_SUDO=$TRUE
                        if sudo cp "$CURRENT_LOC" "$TARGET_LOC"; then
                                sudo chmod +x "$TARGET_LOC"
                                echo $'\nSuccess! Program installed!'
                                echo " > $TARGET_LOC"
                                exit $EXIT_SUCCESS
                        else
                                echo "There was an error when trying to install the program."
                                exit $EXIT_ERROR
                        fi
                else
                        echo "Exiting... (cancelled by user)"
                        exit $EXIT_ERROR
                fi
        fi
        exit $EXIT_ERROR
}

# Tries to download with curl or wget
getUrl() {
        useInsecure && echo $'\nHTTPS Insecure flag is enabled!\nCertificates will be ignored by curl/wget\n'
        local url="$1"
        local target="$2"
        local _stat=""
        if isEmpty "$url" || isEmpty "$target"; then 
                echo "Error! Invalid parameters for download."
                echo "URL    > $url"
                echo "TARGET > $target"
                exit $EXIT_INVALID_OPTION
        fi
        WGET_BIN="$(command -v wget 2>/dev/null)"
        CURL_BIN="$(command -v curl 2>/dev/null)"
        if isExecutable "$WGET_BIN"; then
                useInsecure && WGET_BIN="$WGET_BIN --no-check-certificate"
                echo "Downloading file with wget"
                _stat="$($WGET_BIN -O "$target" "$url" 2>&1)"
                if [[ $? -eq 0 ]]; then
                        return $TRUE
                else
                        echo "Error when downloading file!"
                        echo " > $url"
                        echo "Status:"
                        echo "$_stat"
                        exit $EXIT_ERROR
                fi
        elif isExecutable "$CURL_BIN"; then
                useInsecure && CURL_BIN="$CURL_BIN --insecure"
                echo "Downloading file with curl"
                _stat="$($CURL_BIN -o "$target" -L "$url" 2>&1)"
                if [[ $? -eq 0 ]]; then
                        return $TRUE
                else
                        echo "Error when downloading file!"
                        echo " > $url"
                        echo "Status:"
                        echo "$_stat"
                        exit $EXIT_ERROR
                fi
        else
                echo "Error! Could not find Wget or Curl to perform download."
                echo "Please install either curl or wget and try again."
                exit $EXIT_FILE_NOT_FOUND
        fi
}

# Tries to remove temporary files from upgrade
clearUpgrade() {
        echo $'\nCleaning up downloaded files from /tmp'
        if isFile "$TMP_TARGET"; then
                echo -n " > $TMP_TARGET > "
                rm "$TMP_TARGET" 2>/dev/null && echo "Ok" || echo "Fail"
        else
                echo " > no temporary tarball was found to remove"
        fi
        if isDir "$TMP_EXTRACTED"; then
                echo -n " > $TMP_EXTRACTED > "
                rm -rf "$TMP_EXTRACTED" 2>/dev/null && echo "Ok" || echo "Fail"
        else
                echo " > no temporary master folder was found to remove"
        fi
}

# Exit upgrade with message and status code
# $1 Mensagem (printed if not empty)
# $2 Status   (defaults to $EXIT_ERROR)
exitUpgrade() {
        isDir "$_cwd" && cd "$_cwd"
        isNotEmpty "$1" && echo "$1"
        clearUpgrade
        isNotEmpty "$2" && exit $2
        exit $EXIT_ERROR
}

# Downloads current version from github's MASTER branch
selfUpgrade() {
        #CURRENT_LOC="$(readlink -f $0)"
        CURRENT_LOC="$(readlinkf $0)"
        _cwd="$(pwd)"
        local _cur_tstamp="$(date '+%Y%m%d-%H%M%S')"
        TMP_DIR='/tmp'
        TMP_TARGET="$TMP_DIR/pdfScale_$_cur_tstamp.tar.gz"
        TMP_EXTRACTED="$TMP_DIR/$PROJECT_NAME-$PROJECT_BRANCH"
        
        local _answer="no"
        
        printVersion 3 " - Self Upgrade"
        echo $'\n'"Preparing download to temp folder"
        echo " > $TMP_TARGET"
        getUrl "$PROJECT_URL/archive/$PROJECT_BRANCH.tar.gz" "$TMP_TARGET"
        if isNotFile "$TMP_TARGET"; then 
                echo "Error! Could not find downloaded file!"
                exit $EXIT_FILE_NOT_FOUND
        fi
        echo $'\n'"Extracting compressed file"
        cd "$TMP_DIR"
        if ! (tar xzf "$TMP_TARGET" 2>/dev/null || gtar xzf "$TMP_TARGET" 2>/dev/null); then
                exitUpgrade "Extraction error."
        fi
        if ! cd "$TMP_EXTRACTED" 2>/dev/null; then
                exitUpgrade $'Error when accessing temporary folder\n > '"$TMP_EXTRACTED"
        fi
        if ! chmod +x pdfScale.sh; then
                exitUpgrade $'Error when setting new pdfScale to executable\n > '"$TMP_EXTRACTED/pdfScale.sh"
        fi
        local newver="$(./pdfScale.sh --version 2>/dev/null)"
        local curver="$(printVersion 3 2>/dev/null)"
        newver=($newver)
        curver=($curver)
        newver=${newver[1]#v}
        curver=${curver[1]#v}
        echo $'\n'"   Current Version is: $curver"
        echo      "Downloaded Version is: $newver"$'\n'
        if [[ "$newver" = "$curver" ]]; then
                echo "Seems like we have downloaded the same version that is installed."
        elif isBiggerVersion "$newver" "$curver"; then
                echo "Seems like the downloaded version is newer that the one installed."
        elif isBiggerVersion "$curver" "$newver"; then
                echo "Seems like the downloaded version is older that the one installed."
                echo "It is basically a miracle or you have came from the future with this version!"
                echo "BE CAREFUL NOT TO DELETE THE BETA/ALPHA VERSION WITH THIS UPDATE!"
        else
                exitUpgrade "An unidentified error has ocurred. Exiting..."
        fi
        if assumeYes; then
                echo $'\n'"Assume yes activated, current version will be replaced with master branch"
                _answer="y"
        else
                echo $'\n'"Are you sure that you want to replace the current installation with the downloaded one?"
                read -p "Y/y to continue, anything else to cancel > " _answer
                _answer="$(lowercase $_answer)"
        fi
        echo
        if [[ "$_answer" = "y" || "$_answer" = "yes" ]]; then
                echo "Upgrading..."
                if cp "./pdfScale.sh" "$CURRENT_LOC" 2>/dev/null; then
                        chmod +x "$CURRENT_LOC"
                        exitUpgrade $'\n'"Success! Upgrade finished!"$'\n'" > $CURRENT_LOC" $EXIT_SUCCESS
                else
                        _answer="no"
                        echo $'\n'"There was an error when copying the new version."
                        if assumeYes; then
                                echo $'\nAssume yes activated, retrying with sudo.\nEnter password if needed > \n'
                                _answer="y"
                        else
                                echo "Do you want to retry using sudo (as root)?"
                                read -p "Y/y to continue, anything else to cancel > " _answer
                        fi
                        _answer="$(lowercase $_answer)"
                        if [[ "$_answer" = "y" || "$_answer" = "yes" ]]; then
                                echo "Upgrading with sudo..."
                                if sudo cp "./pdfScale.sh" "$CURRENT_LOC" 2>/dev/null; then
                                        sudo chmod +x "$CURRENT_LOC"
                                        exitUpgrade $'\n'"Success! Upgrade finished!"$'\n'" > $CURRENT_LOC" $EXIT_SUCCESS
                                else
                                        exitUpgrade "There was an error when copying the new version."
                                fi
                        else
                                exitUpgrade "Exiting...  (cancelled by user)"
                        fi

                fi
                exitUpgrade "An unidentified error has ocurred. Exiting..."
        else
                exitUpgrade "Exiting...  (cancelled by user)"
        fi
        exitUpgrade "An unidentified error has ocurred. Exiting..."
}

# Compares versions with x.x.x format
isBiggerVersion() {
        local OIFS=$IFS
        IFS='.'
        local _first=($1)
        local _second=($2)
        local _ret=$FALSE
        
        if [[ ${_first[0]} -gt ${_second[0]} ]]; then
                _ret=$TRUE
        elif [[ ${_first[0]} -lt ${_second[0]} ]]; then
                _ret=$FALSE
        elif [[ ${_first[1]} -gt ${_second[1]} ]]; then
                _ret=$TRUE
        elif [[ ${_first[1]} -lt ${_second[1]} ]]; then
                _ret=$FALSE
        elif [[ ${_first[2]} -gt ${_second[2]} ]]; then
                _ret=$TRUE
        elif [[ ${_first[2]} -lt ${_second[2]} ]]; then
                _ret=$FALSE
        fi
        
        IFS=$OIFS
        return $_ret
}

# Checks if output file is valid and writable
validateOutFile() {
        local _tgtDir="$(dirname "$OUTFILEPDF")"
        isDir "$_tgtDir" || initError "Output directory does not exist!"$'\n'"Target Dir: $_tgtDir" $EXIT_NOWRITE_PERMISSION
        isAbortOnOverwrite && isFile "$OUTFILEPDF" && initError $'Output file already exists and --no-overwrite was used!\nRemove the "-n" or "--no-overwrite" option if you want to overwrite the file\n'"Target File: $OUTFILEPDF" $EXIT_NOWRITE_PERMISSION
        isTouchable "$OUTFILEPDF" || initError "Could not get write permission for output file!"$'\n'"Target File: $OUTFILEPDF"$'\nPermission Denied' $EXIT_NOWRITE_PERMISSION
}

# Returns $TRUE if we should not overwrite $OUTFILEPDF, $FALSE otherwise
isAbortOnOverwrite() {
        return $ABORT_ON_OVERWRITE
}

# Returns $TRUE if we should print the GS call to stdout
shouldPrintGSCall() {
        return $PRINT_GS_CALL
}

# Returns $TRUE if we are simulating, dry-run (no GS execution)
isDryRun() {
        return $SIMULATE
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
                a|auto|automatic|adaptive)
                        ADAPTIVEMODE=$TRUE
                        MODE=""
                        return $TRUE
                        ;;
                *)
                        initError "Invalid PDF Size Detection Mode: \"$1\"" $EXIT_INVALID_OPTION
                        return $FALSE
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
                a|auto|automatic)
                        FLIP_DETECTION=$TRUE
                        FLIP_FORCE=$FALSE
                        ;;
                *)
                        initError "Invalid Flip Detection Mode: \"$1\"" $EXIT_INVALID_OPTION
                        return $FALSE
                        ;;
        esac
}

# Parses and validates the scaling factor
parseAutoRotationMode() {
        local param="$(lowercase $1)"
        case "${param}" in
                n|none|'/none')
                        AUTO_ROTATION='/None'
                        ;;
                a|all|'/all')
                        AUTO_ROTATION='/All'
                        ;;
                p|pagebypage|'/pagebypage'|auto)
                        AUTO_ROTATION='/PageByPage'
                        ;;
                *)
                        initError "Invalid Auto Rotation Mode: \"$1\"" $EXIT_INVALID_OPTION
                        return $FALSE
                        ;;
        esac
}

# Parses and validates the Print Mode (dPrinted parameter)
parsePrintMode() {
        local param="$(lowercase $1)"
        case "${param}" in
                s|screen)
                        DPRINTED='-dPrinted=false'
                        ;;
                p|print|printer)
                        DPRINTED='-dPrinted'
                        ;;
                *)
                        initError "Invalid Print Mode (not s,screen,p,print): \"$1\"" $EXIT_INVALID_OPTION
                        return $FALSE
                        ;;
        esac
}

# Validades the a paper resize CLI option and sets the paper to $RESIZE_PAPER_TYPE
parsePaperResize() {
        isEmpty "$1" && initError 'Invalid Paper Type: (empty)' $EXIT_INVALID_PAPER_SIZE
        local lowercasePaper="$(lowercase $1)"
        local customPaper=($lowercasePaper)
        if [[ "$customPaper" = 'same' || "$customPaper" = 'keep' || "$customPaper" = 'source' ]]; then
                RESIZE_PAPER_TYPE='source'
        elif [[ "${customPaper[0]}" = 'custom' ]]; then
                if isNotValidMeasure "${customPaper[1]}" || ! isFloatBiggerThanZero "${customPaper[2]}" || ! isFloatBiggerThanZero "${customPaper[3]}"; then
                        initError "Invalid Custom Paper Definition!"$'\n'"Use: -r 'custom <measurement> <width> <height>'"$'\n'"Measurements: mm, in, pts" $EXIT_INVALID_OPTION
                fi
                RESIZE_PAPER_TYPE="custom"
                CUSTOM_RESIZE_PAPER=$TRUE
                if isMilimeter "${customPaper[1]}"; then
                        RESIZE_WIDTH="$(milimetersToPoints "${customPaper[2]}")"
                        RESIZE_HEIGHT="$(milimetersToPoints "${customPaper[3]}")"
                elif isInch "${customPaper[1]}"; then
                        RESIZE_WIDTH="$(inchesToPoints "${customPaper[2]}")"
                        RESIZE_HEIGHT="$(inchesToPoints "${customPaper[3]}")"
                elif isPoint "${customPaper[1]}"; then
                        RESIZE_WIDTH="${customPaper[2]}"
                        RESIZE_HEIGHT="${customPaper[3]}"
                else
                        initError "Invalid Custom Paper Definition!"$'\n'"Use: -r 'custom <measurement> <width> <height>'"$'\n'"Measurements: mm, in, pts" $EXIT_INVALID_OPTION
                fi
        else
                isPaperName "$lowercasePaper" || initError "Invalid Paper Type: $1" $EXIT_INVALID_PAPER_SIZE
                RESIZE_PAPER_TYPE="$lowercasePaper"
        fi
}

# Goes to GS -dColorImageResolution and -dGrayImageResolution parameters
parseImageResolution() {
        if isNotAnInteger "$1"; then
                printError "Invalid image resolution: $1"
                printError "The image resolution must be an integer"
                exit $EXIT_INVALID_IMAGE_RESOLUTION
        fi
        IMAGE_RESOLUTION="$1"
}

# Goes to GS -dColorImageDownsampleType and -dGrayImageDownsampleType parameters
parseImageDownSample() {
        local param="$(lowercase $1)"
        case "${param}" in
                s|subsample|'/subsample')
                        IMAGE_DOWNSAMPLE_TYPE='/Subsample'
                        ;;
                a|average|'/average')
                        IMAGE_DOWNSAMPLE_TYPE='/Average'
                        ;;
                b|bicubic|'/bicubic'|auto)
                        IMAGE_DOWNSAMPLE_TYPE='/Bicubic'
                        ;;
                *)
                        initError "Invalid Image Downsample Mode: \"$1\"" $EXIT_INVALID_OPTION
                        return $FALSE
                        ;;
        esac
}

# Goes to GS -dColorImageDownsampleType and -dGrayImageDownsampleType parameters
parsePDFSettings() {
        local param="$(lowercase $1)"
        case "${param}" in
                s|screen|'/screen')
                        PDF_SETTINGS='/screen'
                        ;;
                e|ebook|'/ebook')
                        PDF_SETTINGS='/ebook'
                        ;;
                p|printer|'/printer'|auto)
                        PDF_SETTINGS='/printer'
                        ;;
                r|prepress|'/prepress')
                        PDF_SETTINGS='/prepress'
                        ;;
                d|default|'/default')
                        PDF_SETTINGS='/default'
                        ;;
                *)
                        initError "Invalid PDF Setting Profile: \"$1\""$'\nValid > printer, screen, ebook, prepress, default' $EXIT_INVALID_OPTION
                        return $FALSE
                        ;;
        esac
}

# How to position the resized pages (sets translation)
parseHorizontalAlignment() {
        local param="$(lowercase $1)"
        case "${param}" in
                l|left)
                        HOR_ALIGN='LEFT'
                        ;;
                r|right)
                        HOR_ALIGN='RIGHT'
                        ;;
                c|center|middle)
                        HOR_ALIGN='CENTER'
                        ;;
                *)
                        initError "Invalid Horizontal Alignment Setting: \"$1\""$'\nValid > left, right, center' $EXIT_INVALID_OPTION
                        return $FALSE
                        ;;
        esac
}

# How to position the resized pages (sets translation)
parseVerticalAlignment() {
        local param="$(lowercase $1)"
        case "${param}" in
                t|top)
                        VERT_ALIGN='TOP'
                        ;;
                b|bottom|bot)
                        VERT_ALIGN='BOTTOM'
                        ;;
                c|center|middle)
                        VERT_ALIGN='CENTER'
                        ;;
                *)
                        initError "Invalid Vertical Alignment Setting: \"$1\""$'\nValid > top, bottom, center' $EXIT_INVALID_OPTION
                        return $FALSE
                        ;;
        esac
}

# Set X Translation Offset
parseXTransOffset() {
        if isFloat "$1"; then
                XTRANSOFFSET="$1"
                return $TRUE
        fi
        printError "Invalid X Translation Offset: $1"
        printError "The X Translation Offset must be a floating point number"
        exit $EXIT_INVALID_OPTION
}

# Set Y Translation Offset
parseYTransOffset() {
        if isFloat "$1"; then
                YTRANSOFFSET="$1"
                return $TRUE
        fi
        printError "Invalid Y Translation Offset: $1"
        printError "The Y Translation Offset must be a floating point number"
        exit $EXIT_INVALID_OPTION
}

# Parse Gray Background color
parseGrayBackground() {
        if isFloatPercentage "$1"; then
                BACKGROUNDCOLOR="$1"
                BACKGROUNDCALL="$BACKGROUNDCOLOR setgray clippath fill " # the space at the end is important!
                BACKGROUNDTYPE="GRAY"
                BACKGROUNDLOG="$GrayColor Mode > $BACKGROUNDCOLOR"
                return $TRUE
        fi
        printError "Invalid Gray Background color."
        printError "Need 1 floating point number between 0 and 1."
        printError "Eg: --background-gray \"0.80\""
        printError "Invalid Param => $1"
        exit $EXIT_INVALID_OPTION
}

# Parse CMYK Background color
parseCMYKBackground() {
        if isFloatPercentage "$1" && isFloatPercentage "$2" && isFloatPercentage "$3" && isFloatPercentage "$4"; then
                BACKGROUNDCOLOR="$1 $2 $3 $4"
                BACKGROUNDCALL="$BACKGROUNDCOLOR setcmykcolor clippath fill " # the space at the end is important!
                BACKGROUNDTYPE="CMYK"
                BACKGROUNDLOG="$BACKGROUNDTYPE Mode > $BACKGROUNDCOLOR"
                return $TRUE
        fi
        printError "Invalid CMYK Background colors."
        printError "Need 4 floating point numbers between 0 and 1 in CMYK order."
        printError "Eg: --background-cmyk \"C M Y K\""
        printError "  [C] => $1"
        printError "  [M] => $2"
        printError "  [Y] => $3"
        printError "  [K] => $4"
        exit $EXIT_INVALID_OPTION
}

# Just loads the RGB Vars (without testing anything)
loadRGBVars(){
        local rP="$(rgbToPercentage $1)"
        local gP="$(rgbToPercentage $2)"
        local bP="$(rgbToPercentage $3)"
        BACKGROUNDCOLOR="$rP $gP $bP"
        BACKGROUNDCALL="$BACKGROUNDCOLOR setrgbcolor clippath fill " # the space at the end is important!
        BACKGROUNDTYPE="RGB"
        BACKGROUNDLOG="$BACKGROUNDTYPE Mode > $1($(printf %.2f $rP)) $2($(printf %.2f $gP)) $3($(printf %.2f $bP))"
}

# Converts 255-based RGB to Percentage
rgbToPercentage() {
        local per=$(echo "scale=8; $1 / 255" | "$BCBIN")
        printf '%.7f' "$per"    # Print rounded conversion
}

# Parse RGB Background color
parseRGBBackground() {
        if isRGBInteger "$1" && isRGBInteger "$2" && isRGBInteger "$3" ; then
                loadRGBVars "$1" "$2" "$3"
                return $TRUE
        fi
        printError "Invalid RGB Background colors. Need 3 parameters in  RGB order."
        printError "Numbers must be RGB integers between 0 and 255."
        printError "Eg: --background-rgb \"34 123 255\"" 
        printError "  [R] => $1"
        printError "  [G] => $2"
        printError "  [B] => $3"
        exit $EXIT_INVALID_OPTION
}




# Validades the a paper resize CLI option and sets the paper to $CROPBOX_PAPER_TYPE
parseCropbox() {
        isEmpty "$1" && initError 'Invalid Cropbox: (empty)' $EXIT_INVALID_PAPER_SIZE
        local lowercasePaper="$(lowercase $1)"
        local customPaper=($lowercasePaper)
        if [[ "$customPaper" = 'full' || "$customPaper" = 'fullsize' || "$customPaper" = 'mediabox' ]]; then
                CROPBOX_PAPER_TYPE='fullsize'
        elif [[ "${customPaper[0]}" = 'custom' ]]; then
                if isNotValidMeasure "${customPaper[1]}" || ! isFloatBiggerThanZero "${customPaper[2]}" || ! isFloatBiggerThanZero "${customPaper[3]}"; then
                        initError "Invalid Custom Paper Definition!"$'\n'"Use: --cropbox 'custom <measurement> <width> <height>'"$'\n'"Measurements: mm, in, pts" $EXIT_INVALID_OPTION
                fi
                CROPBOX_PAPER_TYPE="custom"
                CUSTOM_CROPBOX_PAPER=$TRUE
                if isMilimeter "${customPaper[1]}"; then
                        CROPBOX_WIDTH="$(milimetersToPoints "${customPaper[2]}")"
                        CROPBOX_HEIGHT="$(milimetersToPoints "${customPaper[3]}")"
                elif isInch "${customPaper[1]}"; then
                        CROPBOX_WIDTH="$(inchesToPoints "${customPaper[2]}")"
                        CROPBOX_HEIGHT="$(inchesToPoints "${customPaper[3]}")"
                elif isPoint "${customPaper[1]}"; then
                        CROPBOX_WIDTH="${customPaper[2]}"
                        CROPBOX_HEIGHT="${customPaper[3]}"
                else
                        initError "Invalid Custom Paper Definition!"$'\n'"Use: --cropbox 'custom <measurement> <width> <height>'"$'\n'"Measurements: mm, in, pts" $EXIT_INVALID_OPTION
                fi
        else
                isPaperName "$lowercasePaper" || initError "Invalid Paper Type: $1" $EXIT_INVALID_PAPER_SIZE
                CROPBOX_PAPER_TYPE="$lowercasePaper"
                
        fi
        RESIZECOMMANDS='<</EndPage {0 eq {[/CropBox [0 0 '"$CROPBOX_WIDTH $CROPBOX_HEIGHT"'] /PAGE pdfmark true}{false}ifelse}>> setpagedevice'
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
        if isNotFile "$IDBIN" && isNotAdaptiveMode; then
                notAdaptiveFailed "Make sure you installed ImageMagick and have identify on your \$PATH" "ImageMagick's Identify"
        elif isNotFile "$IDBIN" && isAdaptiveMode; then
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
        if isNotFile "$MDLSBIN" && isNotAdaptiveMode; then
                notAdaptiveFailed "Are you even trying this on a Mac?" "Mac Quartz mdls"
        elif isNotFile "$MDLSBIN" && isAdaptiveMode; then
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
        if isNotFile "$PDFINFOBIN" && isNotAdaptiveMode; then
                notAdaptiveFailed "Do you have pdfinfo installed and available on your \$PATH?" "Linux pdfinfo"
        elif isNotFile "$PDFINFOBIN" && isAdaptiveMode; then
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
        # get MediaBox info from PDF file using grep, these are all possible
        # /MediaBox [0 0 595 841]
        # /MediaBox [ 0 0 595.28 841.89]
        # /MediaBox[ 0 0 595.28 841.89 ]

        # Get MediaBox data if possible
        #local mediaBox="$("$GREPBIN" -a -e '/MediaBox' -m 1 "$INFILEPDF" 2>/dev/null)"
        local mediaBox="$(strings "$INFILEPDF" | "$GREPBIN" -a -e '/MediaBox' -m 1 2>/dev/null)"

        mediaBox="${mediaBox##*/MediaBox}"
        mediaBox="${mediaBox##*[}"
        mediaBox="${mediaBox%%]*}"
        #echo "mediaBox=$mediaBox"

        # No page size data available
        if isEmpty "$mediaBox" && isNotAdaptiveMode; then
                notAdaptiveFailed "There is no MediaBox in the pdf document!"
        elif isEmpty "$mediaBox" && isAdaptiveMode; then
                return $FALSE
        fi

        mediaBox=($mediaBox)        # make it an array
        mbCount=${#mediaBox[@]}     # array size

        # sanity
        if [[ $mbCount -lt 4 ]] || ! isFloat "${mediaBox[2]}" || ! isFloat "${mediaBox[3]}" || isZero "${mediaBox[2]}" || isZero "${mediaBox[3]}"; then 
                if isNotAdaptiveMode; then
                        notAdaptiveFailed $'Error when reading the page size!\nThe page size information is invalid!'
                fi
                return $FALSE
        fi

        # we are done
        PGWIDTH=$(printf '%.0f' "${mediaBox[2]}")  # Get Round Width
        PGHEIGHT=$(printf '%.0f' "${mediaBox[3]}") # Get Round Height

        #echo "PGWIDTH=$PGWIDTH // PGHEIGHT=$PGHEIGHT"
        return $TRUE
}

isZero() {
    [[ "$1" == "0" ]] && return $TRUE
    [[ "$1" == "0.0" ]] && return $TRUE
    [[ "$1" == "0.00" ]] && return $TRUE
    [[ "$1" == "0.000" ]] && return $TRUE
    return $FALSE
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

# Loads valid paper info to memory
getPaperInfo() {
        # name inchesW inchesH mmW mmH pointsW pointsH
        sizesUS="\
11x17 11.0 17.0 279 432 792 1224
ledger 17.0 11.0 432 279 1224 792
legal 8.5 14.0 216 356 612 1008
letter 8.5 11.0 216 279 612 792
lettersmall 8.5 11.0 216 279 612 792
arche 36.0 48.0 914 1219 2592 3456
archd 24.0 36.0 610 914 1728 2592
archc 18.0 24.0 457 610 1296 1728
archb 12.0 18.0 305 457 864 1296
archa 9.0 12.0 229 305 648 864"

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
getCropboxPaperSize() {
        isEmpty "$sizesall" && getPaperInfo
        while read l; do 
                local cols=($l)
                if [[ "$1" == ${cols[0]} ]]; then
                        CROPBOX_WIDTH=${cols[5]}
                        CROPBOX_HEIGHT=${cols[6]}
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
11x17 ledger legal letter lettersmall arche archd archc archb archa \
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
        printVersion 3
        echo $'\n'"Paper Sizes Information"$'\n'
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

# Returns $FALSE if a custom paper is being used, $TRUE otherwise
isNotCustomPaper() {
        isCustomPaper && return $FALSE
        return $TRUE
}

# Returns $TRUE if a custom paper is being used, $FALSE otherwise
isCustomCropbox() {
        return $CUSTOM_CROPBOX_PAPER
}

# Returns $FALSE if a custom paper is being used, $TRUE otherwise
isNotCustomCropbox() {
        isCustomCropbox && return $FALSE
        return $TRUE
}


######################### CONVERSIONS ##########################

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


######################## MODE-DETECTION ########################

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

# Returns true if we are reseting the cropboxes (ignores scaling), false otherwise
shouldSetCropbox() {
        isEmpty $CROPBOX_PAPER_TYPE && return $FALSE
        return $TRUE
}

# Returns true if we are resizing a paper and the scale was manually set
isMixedMode() {
        isResizeMode && isManualScaledMode && return $TRUE
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


########################## VALIDATORS ##########################

# Returns $TRUE if we don't need to create a background
noBackground() {
        [[ "$BACKGROUNDTYPE" == "CMYK" ]] && return $FALSE
        [[ "$BACKGROUNDTYPE" == "RGB" ]] && return $FALSE
        [[ "$BACKGROUNDTYPE" == "GRAY" ]] && return $FALSE
        return $TRUE
}

# Returns $TRUE if we need to create a background
hasBackground() {
        [[ "$BACKGROUNDTYPE" == "CMYK" ]] && return $TRUE
        [[ "$BACKGROUNDTYPE" == "RGB" ]] && return $TRUE
        [[ "$BACKGROUNDTYPE" == "GRAY" ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $PGWIDTH OR $PGWIDTH are empty or NOT an Integer, $FALSE otherwise
pageSizeIsInvalid() {
        if isNotAnInteger "$PGWIDTH" || isNotAnInteger "$PGHEIGHT"; then
                return $TRUE
        fi
        return $FALSE
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

# Returns $TRUE if $1 is an integer, $FALSE otherwise
isRGBInteger() {
        isAnInteger "$1" && [[ $1 -ge 0 ]] && [[ $1 -le 255 ]] && return $TRUE 
        return $FALSE
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

# Returns $TRUE if $1 is a floating point number between 0 and 1, $FALSE otherwise
isFloatPercentage() {
        [[ -n "$1" && "$1" =~ ^-?[0]*([.][0-9]+)?$ ]] && return $TRUE
        [[ "$1" == "1" ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $1 is readable, $FALSE otherwise
isReadable() {
        [[ -r "$1" ]] && return $TRUE
        return $FALSE;
}

# Returns $TRUE if $1 is a directory, $FALSE otherwise
isDir() {
        [[ -d "$1" ]] && return $TRUE
        return $FALSE;
}

# Returns $FALSE if $1 is a directory, $TRUE otherwise
isNotDir() {
        isDir "$1" && return $FALSE
        return $TRUE;
}

# Returns 0 if succeded, other integer otherwise
isTouchable() {
        touch "$1" 2>/dev/null
}

# Returns $TRUE if $1 has a .pdf extension, false otherwsie
isPDF() {
        [[ "$(lowercase $1)" =~ ^..*\.pdf$ ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $1 is a file, false otherwsie
isFile() {
        [[ -f "$1" ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $1 is NOT a file, false otherwsie
isNotFile() {
        [[ -f "$1" ]] && return $FALSE
        return $TRUE
}

# Returns $TRUE if $1 is executable, false otherwsie
isExecutable() {
        [[ -x "$1" ]] && return $TRUE
        return $FALSE
}

# Returns $TRUE if $1 is NOT executable, false otherwsie
isNotExecutable() {
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
isNotAvailable() {
        if isNotFile "$1" || isNotExecutable "$1"; then 
                return $TRUE
        fi
        return $FALSE
}

# Returns $TRUE if we should avoid https certificate (on upgrade)
useInsecure() {
        return $HTTPS_INSECURE
}

# Returns $TRUE if we should not ask anything and assume yes as answer
assumeYes() {
        return $ASSUME_YES
}

# Returns $TRUE if we should ask the user for input
shouldAskUser() {
        assumeYes && return $FALSE
        return $TRUE
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

# Prints input, output file info, if verbosing
vPrintFileInfo() {
        vprint "    Input File: $INFILEPDF"
        vprint "   Output File: $OUTFILEPDF"
}

# Prints the scale factor to screen, or custom message
vPrintScaleFactor() {
        local scaleMsg="$SCALE"
        isNotEmpty "$1" && scaleMsg="$1"
        vprint "  Scale Factor: $scaleMsg"
}

# Prints -dPrinted info to verbose log
vShowPrintMode() {
	local pMode
	pMode='Print ( -dPrinted )'
	if [[ -z "$DPRINTED" ]]; then
		pMode='Print ( auto/empty )'
	elif [[ "$DPRINTED" = '-dPrinted=false' ]]; then
		pMode='Screen ( -dPrinted=false )'
	fi
	vprint "    Print Mode: $pMode"
}

# Prints help info
printHelp() {
        printVersion 3
        #local paperList="$(printPaperNames)"
#        echo "
        printf "%s" "
Usage: $PDFSCALE_NAME <inFile.pdf>
       $PDFSCALE_NAME -i <inFile.pdf>
       $PDFSCALE_NAME [-v] [-s <factor>] [-m <page-detection>] <inFile.pdf> [outfile.pdf]
       $PDFSCALE_NAME [-v] [-r <paper>] [-f <flip-detection>] [-a <auto-rotation>] <inFile.pdf> [outfile.pdf]
       $PDFSCALE_NAME -p
       $PDFSCALE_NAME -h
       $PDFSCALE_NAME -V

Parameters:
 -v, --verbose
             Verbose mode, prints extra information
             Use twice for timestamp
 -h, --help  
             Print this help to screen and exits
 -V, --version
             Prints version to screen and exits
 --install, --self-install [target-path]
             Install itself to [target-path] or /usr/local/bin/pdfscale if not specified
             Should contain the full path with the desired executable name
 --upgrade, --self-upgrade
             Upgrades itself in-place (same path/name of the pdfScale.sh caller)
             Downloads the master branch tarball and tries to self-upgrade
 --insecure, --no-check-certificate
             Use curl/wget without SSL library support
 --yes, --assume-yes
             Will answer yes to any prompt on install or upgrade, use with care
 -n, --no-overwrite
             Aborts execution if the output PDF file already exists
             By default, the output file will be overwritten
 -m, --mode <mode>
             Paper size detection mode 
             Modes: a, adaptive  Default mode, tries all the methods below
                    g, grep      Forces the use of Grep method
                    m, mdls      Forces the use of MacOS Quartz mdls
                    p, pdfinfo   Forces the use of PDFInfo
                    i, identify  Forces the use of ImageMagick's Identify
 -i, --info <file>
             Prints <file> Paper Size information to screen and exits
 -s, --scale <factor>
             Changes the scaling factor or forces mixed mode
             Defaults: $SCALE (scale mode) / Disabled (resize mode)
             MUST be a number bigger than zero
             Eg. -s 0.8 for 80% of the original size
 -r, --resize <paper>
             Triggers the Resize Paper Mode, disables auto-scaling of $SCALE
             Resize PDF and fit-to-page
             <paper> can be: source, custom or a valid std paper name, read below
 -c, --cropbox <paper>
             Resets Cropboxes on all pages to a specific paper size
             Only applies to resize mode
             <paper> can be: full | fullsize - Uses the same size as the main paper/mediabox
                             custom          - Define a custom cropbox size in inches, mm or points
                             std paper name  - Uses a paper size name (eg. a4, letter, etc)
 -f, --flip-detect <mode>
             Flip Detection Mode, defaults to 'auto'
             Inverts Width <-> Height of a Resized PDF
             Modes: a, auto     Keeps source orientation, default
                    f, force    Forces flip W <-> H
                    d, disable  Disables flipping 
 -a, --auto-rotate <mode>
             Setting for GS -dAutoRotatePages, defaults to 'PageByPage'
             Uses text-orientation detection to set Portrait/Landscape
             Modes: p, pagebypage  Auto-rotates pages individually
                    n, none        Retains orientation of each page
                    a, all         Rotates all pages (or none) depending
                                   on a kind of \"majority decision\"
 --no-fit-to-page
             Disables GS option dPDFFitPage (used when resizing)
 --hor-align, --horizontal-alignment <left|center|right>
             Where to translate the scaled page
             Default: center
             Options: left, right, center
 --vert-align, --vertical-alignment <top|center|bottom>
             Where to translate the scaled page
             Default: center
             Options: top, bottom, center
 --xoffset, --xtrans-offset <FloatNumber>
             Add/Subtract from the X translation (move left-right)
             Default: 0.0 (zero)
             Options: Positive or negative floating point number
 --yoffset, --ytrans-offset <FloatNumber>
             Add/Subtract from the Y translation (move top-bottom)
             Default: 0.0 (zero)
             Options: Positive or negative floating point number
 --pdf-settings <gs-pdf-profile>
             Ghostscript PDF Profile to use in -dPDFSETTINGS
             Default: printer
             Options: screen, ebook, printer, prepress, default
 --print-mode <mode>
             Setting for GS -dPrinted, loads options for screen or printer
             Defaults to nothing, which uses the print profile for files
             The screen profile preserves URLs, but loses print annotations
             Modes: s, screen   Use screen options > '-dPrinted=false'
                    p, printer  Use print options  > '-dPrinted'
 --image-downsample <gs-downsample-method>
             Ghostscript Image Downsample Method
             Default: bicubic
             Options: subsample, average, bicubic
 --image-resolution <dpi>
             Resolution in DPI of color and grayscale images in output
             Default: 300
 --background-gray <percentage>
             Creates a background with a gray color setting on PDF scaling
             Percentage is a floating point percentage number between 0(black) and 1(white)
 --background-cmyk <\"C M Y K\">
             Creates a background with a CMYK color setting on PDF scaling
             Must be quoted into a single parameter as in \"0.2 0.2 0.2 0.2\"
             Each color parameter is a floating point percentage number (between 0 and 1)
 --background-rgb <\"R G B\">
             Creates a background with a RGB color setting on PDF scaling
             Must be quoted into a single parameter as in \"100 100 200\"
             RGB numbers are integers between 0 and 255 (255 122 50)
 --dry-run, --simulate
             Just simulate execution. Will not run ghostscript
 --print-gs-call, --gs-call
             Print GS call to stdout. Will print at the very end between markers
 -p, --print-papers
             Prints Standard Paper info tables to screen and exits

Scaling Mode:
 - The default mode of operation is scaling mode with fixed paper
   size and scaling pre-set to $SCALE
 - By not using the resize mode you are using scaling mode
 - Flip-Detection and Auto-Rotation are disabled in Scaling mode,
   you can use '-r source -s <scale>' to override. 
 - Ghostscript placement is from bottom-left position. This means that
   a bottom-left placement has ZERO for both X and Y translations.

Resize Paper Mode:
 - Disables the default scaling factor! ($SCALE)
 - Changes the PDF Paper Size in points. Will fit-to-page

Mixed Mode:
 - In mixed mode both the -s option and -r option must be specified
 - The PDF will be first resized then scaled

Output filename:
 - Having the extension .pdf on the output file name is optional,
   it will be added if not present.
 - The output filename is optional. If no file name is passed
   the output file will have the same name/destination of the
   input file with added suffixes:
   .SCALED.pdf             is added to scaled files
   .<PAPERSIZE>.pdf        is added to resized files
   .<PAPERSIZE>.SCALED.pdf is added in mixed mode

Standard Paper Names: (case-insensitive)
 A0            A1            A2            A3            A4
 A4SMALL       A5            A6            A7            A8
 A9            A10           ISOB0         ISOB1         ISOB2
 ISOB3         ISOB4         ISOB5         ISOB6         C0
 C1            C2            C3            C4            C5
 C6            11X17         LEDGER        LEGAL         LETTER
 LETTERSMALL   ARCHE         ARCHD         ARCHC         ARCHB
 ARCHA         JISB0         JISB1         JISB2         JISB3
 JISB4         JISB5         JISB6         FLSA          FLSE
 HALFLETTER    HAGAKI

Custom Paper Size:
 - Paper size can be set manually in Milimeters, Inches or Points
 - Custom paper definition MUST be quoted into a single parameter
 - Actual size is applied in points (mms and inches are transformed)
 - Measurements: mm, mms,  milimeters 
                 pt, pts,  points
                 in, inch, inches
 Use: $PDFSCALE_NAME -r 'custom <measurement> <width> <height>'
 Ex:  $PDFSCALE_NAME -r 'custom mm 300 300'

Using Source Paper Size: (no-resizing)
 - Wildcard 'source' is used used to keep paper size the same as the input
 - Usefull to run Auto-Rotation without resizing
 - Eg. $PDFSCALE_NAME -r source ./input.pdf

Backgrounding: (paint a background)
 - Backgrounding only happens when scaling
 - Use a scale of 1.0 to force mixed mode and add background while resizing
 
Options and Parameters Parsing:
 - From v2.1.0 (long-opts) there is no need to pass file names at the end
 - Anything that is not a short-option is case-insensitive
 - Short-options: case-sensitive   Eg. -v for Verbose, -V for Version
 - Long-options:  case-insensitive Eg. --SCALE and --scale are the same
 - Subparameters: case-insensitive Eg. -m PdFinFo is valid
 - Grouping short-options is not supported Eg. -vv, or -vs 0.9

Additional Notes:
 - File and folder names with spaces should be quoted or escaped
 - Using a scale bigger than 1.0 may result on cropping parts of the PDF
 - For detailed paper types information, use: $PDFSCALE_NAME -p

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
        isNotEmpty "$1" && printError $'\n'"$1"
        printError $'\n'"Usage: $PDFSCALE_NAME [-v] [-s <factor>] [-m <mode>] [-r <paper> [-f <mode>] [-a <mode>]] <inFile.pdf> [outfile.pdf]"
        printError "Help : $PDFSCALE_NAME -h"
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
        printVersion 2
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



##############################################################################
## REALPATH IMPLEMENTATION
## https://github.com/mkropat/sh-realpath/blob/master/realpath.sh

realpath() {
    canonicalize_path "$(resolve_symlinks "$1")"
}

resolve_symlinks() {
    _resolve_symlinks "$1"
}

_resolve_symlinks() {
    _assert_no_path_cycles "$@" || return

    local dir_context path
    path=$(readlink -- "$1")
    if [ $? -eq 0 ]; then
        dir_context=$(dirname -- "$1")
        _resolve_symlinks "$(_prepend_dir_context_if_necessary "$dir_context" "$path")" "$@"
    else
        printf '%s\n' "$1"
    fi
}

_prepend_dir_context_if_necessary() {
    if [ "$1" = . ]; then
        printf '%s\n' "$2"
    else
        _prepend_path_if_relative "$1" "$2"
    fi
}

_prepend_path_if_relative() {
    case "$2" in
        /* ) printf '%s\n' "$2" ;;
         * ) printf '%s\n' "$1/$2" ;;
    esac
}

_assert_no_path_cycles() {
    local target path

    target=$1
    shift

    for path in "$@"; do
        if [ "$path" = "$target" ]; then
            return 1
        fi
    done
}

canonicalize_path() {
    if [ -d "$1" ]; then
        _canonicalize_dir_path "$1"
    else
        _canonicalize_file_path "$1"
    fi
}

_canonicalize_dir_path() {
    (cd "$1" 2>/dev/null && pwd -P)
}

_canonicalize_file_path() {
    local dir file
    dir=$(dirname -- "$1")
    file=$(basename -- "$1")
    (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$file")
}


##############################################################################
## READLINK -F IMPLEMENTATION
## Running a native bash readlink -f substitute

# Resolve symlinks
function tracelink() {
        local link="$1"
        while [ -L "$link" ]; do
                lastLink="$link"
                link=$(/bin/ls -ldq "$link")
                link="${link##* -> }"
                link=$(realpath "$link")
                [ "$link" == "$lastlink" ] && echo -e "ERROR: link loop or inexistent target detected on $link" 1>&2 && break
        done
        echo -n "$link"
}

# Traverse path
function abspath() {
        pushd . > /dev/null;
        if [ -d "$1" ]; then
                cd "$1";
                dirs -l +0;
        else
                cd "`dirname \"$1\"`";
                cur_dir=`dirs -l +0`;
                if [ "$cur_dir" == "/" ]; then
                        echo -n "$cur_dir`basename \"$1\"`";
                else
                        echo -n "$cur_dir/`basename \"$1\"`";
                fi;
        fi;
        popd > /dev/null;
}

# Uses tracelink and abspath to emulate readlink -f
function readlinkf() {
        echo -n "$(tracelink "$(abspath "$1")")"
}





########################## EXECUTION ###########################

initDeps
getOptions "${@}"
main
exit $?
