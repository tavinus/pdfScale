#!/usr/bin/env bash

# pdfScale.sh
#
# Scale PDF to specified percentage of original size.
#
# Gustavo Arnosti Neves - 2016 / 07 / 10
#        Latest Version - 2017 / 05 / 19
#
# This script: https://github.com/tavinus/pdfScale
#    Based on: http://ma.juii.net/blog/scale-page-content-of-pdf-files
#         And: https://gist.github.com/MichaelJCole/86e4968dbfc13256228a


VERSION="2.1.2"


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
FLIP_DETECTION=$TRUE        # If we should run the Flip-detection
FLIP_FORCE=$FALSE           # If we should force Flipping
AUTO_ROTATION='/PageByPage' # GS call auto-rotation setting
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
EXIT_NOWRITE_PERMISSION=29
EXIT_NOREAD_PERMISSION=30
EXIT_TEMP_FILE_EXISTS=40
EXIT_INVALID_PAPER_SIZE=50


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
                isFile "$tempFile" && rm "$tempFile" >/dev/null 2>&1 || printError "Error when removing temporary file: $tempFile"
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
                vprint "  Final Status: File created successfully"
        else
                vprint "  Final Status: Error detected. Exit status: $finalRet"
                printError "PdfScale: ERROR!"$'\n'"Ghostscript Debug Info:"$'\n'"$GS_RUN_STATUS"
        fi

        return $finalRet
}

# Initializes PDF processing for all modes of operation
initMain() {
        printVersion 1 'verbose'
        isNotEmpty "$1" && vprint "$1"
        vPrintFileInfo
        getPageSize
        vPrintPageSizes ' Source'
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
        # Compute translation factors (to center page).
        XTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGWIDTH" | "$BCBIN")
        YTRANS=$(echo "scale=6; 0.5*(1.0-$SCALE)/$SCALE*$PGHEIGHT" | "$BCBIN")
        vprint " Translation X: $XTRANS"
        vprint " Translation Y: $YTRANS"

        local increase=$(echo "scale=0; (($SCALE - 1) * 100)/1" | "$BCBIN")
        vprint "   Run Scaling: $increase %"

        GS_RUN_STATUS="$GS_RUN_STATUS""$(gsPageScale 2>&1)"
        return $? # Last command is always returned I think
}

# Runs GS call for scaling, nothing else should run here
gsPageScale() {
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
        # Get paper sizes from source if not resizing
        isResizePaperSource && { RESIZE_WIDTH=$PGWIDTH; RESIZE_HEIGHT=$PGHEIGHT; }
        # Get new paper sizes if not custom or source paper
        isNotCustomPaper && ! isResizePaperSource && getGSPaperSize "$RESIZE_PAPER_TYPE"
        vprint "   Auto Rotate: $(basename $AUTO_ROTATION)"
        runFlipDetect
        vprint "  Run Resizing: $(uppercase "$RESIZE_PAPER_TYPE") ( "$RESIZE_WIDTH" x "$RESIZE_HEIGHT" ) pts"
        GS_RUN_STATUS="$GS_RUN_STATUS""$(gsPageResize 2>&1)"
        return $?
}

# Runs GS call for resizing, nothing else should run here
gsPageResize() {
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
        GREPBIN="$(which grep 2>/dev/null)"
        GSBIN="$(which gs 2>/dev/null)"
        BCBIN="$(which bc 2>/dev/null)"
        IDBIN=$(which identify 2>/dev/null)
        MDLSBIN="$(which mdls 2>/dev/null)"
        PDFINFOBIN="$(which pdfinfo 2>/dev/null)"
        
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
                *)
                        initError "Invalid Parameter: \"$1\"" $EXIT_INVALID_OPTION
                        ;;
            esac
        done

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
                        initError "Invalid Auto Rotation Mode: \"$1\"" $EXIT_INVALID_OPTION
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
        local mediaBox="$("$GREPBIN" -a -e '/MediaBox' -m 1 "$INFILEPDF" 2>/dev/null)"

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

# Loads valid paper info to memory
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
 -v, --verbose
             Verbose mode, prints extra information
             Use twice for timestamp
 -h, --help  
             Print this help to screen and exits
 -V, --version
             Prints version to screen and exits
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
 -p, --print-papers
             Prints Standard Paper info tables to screen and exits

Scaling Mode:
 - The default mode of operation is scaling mode with fixed paper
   size and scaling pre-set to $SCALE
 - By not using the resize mode you are using scaling mode
 - Flip-Detection and Auto-Rotation are disabled in Scaling mode,
   you can use '-r source -s <scale>' to override. 

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
$paperList

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
 - Eg. $PDFSCALE_NAME -r source ./input.dpf

Options and Parameters Parsing:
 - From v2.1.0 (long-opts) there is no need to pass file names at the end
 - Anything that is not a short-option is case-insensitive
 - Short-options: case-sensitive   Eg. -v for Verbose, -V for Version
 - Long-options:  case-insensitive Eg. --SCALE and --scale are the same
 - Subparameters: case-insensitive Eg. -m PdFinFo is valid
 - Grouping short-options is not supported Eg. -vv, or -vs 0.9

Additional Notes:
 - File and folder names with spaces should be quoted or escaped
 - The scaling is centered and using a scale bigger than 1.0 may
   result on cropping parts of the PDF
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


########################## EXECUTION ###########################

initDeps
getOptions "${@}"
main
exit $?
