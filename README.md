# pdfScale 2
Bash Script to ***scale*** and/or ***resize*** PDFs from the command line.  
Uses ghostscript (`gs`) to create a scaled and/or resized version of the pdf input.  

In `scaling mode`, the PDF paper size does not change, just the elements are scaled.  
In `resize mode`, the PDF paper will be changed and fit-to-page will be applied.  
In `mixed mode`, the PDF will first be `resized` then `scaled` with two Ghostscript calls.  
A temporary file is used in `mixed mode`, at the target location.  
  
---------------------------------------------- 
#### If you want to support this project, you can do it here :coffee: :beer:   
  
[![paypal-image](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=HP344TKTWXFXE&source=url)   

----------------------------------------------  
  
## Example Runs
Better than explaining is showing it:  
#### Checking File Information
```
$ ./pdfScale.sh -i test.pdf
pdfScale.sh v2.6.2 - Paper Sizes
-------------+-----------------------------
        File | test.pdf
  Paper Type | A4 Portrait
       Pages | 4
-------------+-----------------------------
  FIRST PAGE |    WIDTH x HEIGHT
      Points |      595 x 842
 Millimeters |      210 x 297
      Inches |      8.3 x 11.7
-------------+-----------------------------
   ALL PAGES |    WIDTH x HEIGHT (pts)
           1 |      595 x 842
           2 |      595 x 842
           3 |      595 x 842
           4 |      595 x 842
-------------+-----------------------------
```
#### Scale by 0.95 (-5%)
This also shows a very special case of a PDF file that has no `/MediaBox` defined.  
It is a dumb container of n-up binary PDF pages.  
`Ggrep` fails, then `PDFInfo` fails (not installed), then ImageMagick fails (not installed) and then the Ghostscript PS script does the job .  
This was on CygWin64 `@` Windows11 x64, MacOS would try `mdls` as well.
```
$ ./pdfScale.sh -v ../input-nup.pdf
pdfScale.sh v2.6.2 - Verbose Execution
   Single Task: Scale PDF Contents
       Dry-Run: FALSE
    Input File: ../input-nup.pdf
   Output File: ../input-nup.SCALED.pdf
   Explode PDF: Disabled
 Get Page Size: Adaptive Enabled
        Method: Grep
                Failed, trying next method
        Method: PDFInfo
                Failed, trying next method
        Method: ImageMagick's Identify
                Failed, trying next method
        Method: Ghostscript PS Script
    Page Range: None (all pages)
  Source Width: 842 postscript-points
 Source Height: 595 postscript-points
    Print Mode: Print ( auto/empty )
  Scale Factor: 0.95 (auto)
 Scale Percent: -5%
    Vert-Align: CENTER
     Hor-Align: CENTER
 Translation X: 22.16 = 22.16 + 0.00 (offset)
 Translation Y: 15.66 = 15.66 + 0.00 (offset)
    Background: No background (default)
  Final Status: File created successfully
```
#### Resize to A0 and Scale by 1.05 (+5%)
```
$ ./pdfScale.sh -v -r a0 -s 1.05 ../mixsync_manual_v1-2-3.pdf
pdfScale.sh v2.6.2 - Verbose Execution
   Mixed Tasks: Resize & Scale
       Dry-Run: FALSE
    Input File: ../mixsync_manual_v1-2-3.pdf
   Output File: ../mixsync_manual_v1-2-3.A0.SCALED.pdf
   Explode PDF: Disabled
 Get Page Size: Adaptive Enabled
        Method: Grep
    Page Range: None (all pages)
  Source Width: 842 postscript-points
 Source Height: 595 postscript-points
    Print Mode: Print ( auto/empty )
   Fit To Page: Enabled (default)
   Auto Rotate: PageByPage
   Flip Detect: Wrong orientation detected!
                Inverting Width <-> Height
  Run Resizing: A0 ( 3370 x 2384 ) pts
     New Width: 3370 postscript-points
    New Height: 2384 postscript-points
  Scale Factor: 1.05
 Scale Percent: +5%
    Vert-Align: CENTER
     Hor-Align: CENTER
 Translation X: -80.24 = -80.24 + 0.00 (offset)
 Translation Y: -56.76 = -56.76 + 0.00 (offset)
    Background: No background (default)
  Final Status: File created successfully
```
#### Resize to A3, Scale by 1.11 (+11%) and Explode the results
*Exploding (splitting) will create a PDF file for each page, with the `.Page#.pdf` suffix*  
```
$ ./pdfScale.sh -v -s 1.11 -r A3 -e ../mixsync_manual_v1-4-2.pdf
pdfScale.sh v2.6.2 - Verbose Execution
   Mixed Tasks: Resize & Scale
       Dry-Run: FALSE
    Input File: ../mixsync_manual_v1-4-2.pdf
   Output File: ../mixsync_manual_v1-4-2.A3.SCALED.Page%d.pdf
   Explode PDF: Enabled
 Get Page Size: Adaptive Enabled
        Method: Grep
    Page Range: None (all pages)
  Source Width: 595 postscript-points
 Source Height: 842 postscript-points
    Print Mode: Print ( auto/empty )
   Fit To Page: Enabled (default)
   Auto Rotate: PageByPage
   Flip Detect: No change needed
  Run Resizing: A3 ( 842 x 1191 ) pts
     New Width: 842 postscript-points
    New Height: 1191 postscript-points
  Scale Factor: 1.11
 Scale Percent: +11%
    Vert-Align: CENTER
     Hor-Align: CENTER
 Translation X: -41.72 = -41.72 + 0.00 (offset)
 Translation Y: -59.01 = -59.01 + 0.00 (offset)
    Background: No background (default)
  Final Status: File created successfully
```
#### Resize to A2 and disables Auto-Rotation
```
$ ./pdfScale.sh -v -r A2 -a none ../input.pdf
pdfScale.sh v2.6.2 - Verbose Execution
   Single Task: Resize PDF Paper
       Dry-Run: FALSE
    Input File: ../input.pdf
   Output File: ../input.A2.pdf
   Explode PDF: Disabled
 Get Page Size: Adaptive Enabled
        Method: Grep
    Page Range: None (all pages)
  Source Width: 595 postscript-points
 Source Height: 842 postscript-points
    Print Mode: Print ( auto/empty )
  Scale Factor: Disabled (resize only)
   Fit To Page: Enabled (default)
   Auto Rotate: None
   Flip Detect: No change needed
  Run Resizing: A2 ( 1191 x 1684 ) pts
  Final Status: File created successfully
```
#### Resize to custom 200x300 mm, disable Flip-Detection and Scale by 0.95 (-5%)
```
$ ./pdfScale.sh  -v -v -r 'custom mm 200 300' -f disable -s 0.95 ../mixsync_manual_v1-2-3.pdf
2024-07-17:14:43:15 | pdfScale.sh v2.6.2 - Verbose Execution
2024-07-17:14:43:15 |    Mixed Tasks: Resize & Scale
2024-07-17:14:43:15 |        Dry-Run: FALSE
2024-07-17:14:43:15 |     Input File: ../mixsync_manual_v1-2-3.pdf
2024-07-17:14:43:15 |    Output File: ../mixsync_manual_v1-2-3.CUSTOM.SCALED.pdf
2024-07-17:14:43:15 |    Explode PDF: Disabled
2024-07-17:14:43:15 |  Get Page Size: Adaptive Enabled
2024-07-17:14:43:15 |         Method: Grep
2024-07-17:14:43:15 |     Page Range: None (all pages)
2024-07-17:14:43:16 |   Source Width: 842 postscript-points
2024-07-17:14:43:16 |  Source Height: 595 postscript-points
2024-07-17:14:43:16 |     Print Mode: Print ( auto/empty )
2024-07-17:14:43:16 |    Fit To Page: Enabled (default)
2024-07-17:14:43:16 |    Auto Rotate: PageByPage
2024-07-17:14:43:16 |    Flip Detect: Disabled
2024-07-17:14:43:16 |   Run Resizing: CUSTOM ( 567 x 850 ) pts
2024-07-17:14:43:16 |      New Width: 567 postscript-points
2024-07-17:14:43:16 |     New Height: 850 postscript-points
2024-07-17:14:43:16 |   Scale Factor: 0.95
2024-07-17:14:43:16 |  Scale Percent: -5%
2024-07-17:14:43:16 |     Vert-Align: CENTER
2024-07-17:14:43:16 |      Hor-Align: CENTER
2024-07-17:14:43:16 |  Translation X: 14.92 = 14.92 + 0.00 (offset)
2024-07-17:14:43:16 |  Translation Y: 22.37 = 22.37 + 0.00 (offset)
2024-07-17:14:43:16 |     Background: No background (default)
2024-07-17:14:43:17 |   Final Status: File created successfully
```

## Help info
```
$ ./pdfScale.sh -h
pdfScale.sh v2.6.2

Usage: pdfScale.sh <inFile.pdf>
       pdfScale.sh -i <inFile.pdf>
       pdfScale.sh [-v] [-s <factor>] [-m <page-detection>] <inFile.pdf> [outfile.pdf]
       pdfScale.sh [-v] [-r <paper>] [-f <flip-detection>] [-a <auto-rotation>] <inFile.pdf> [outfile.pdf]
       pdfScale.sh -p
       pdfScale.sh -h
       pdfScale.sh -V

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
             Does NOT work if using --explode
 -m, --mode <mode>
             Paper size detection mode
             Modes: a, adaptive  Default mode, tries all the methods below
                    g, grep      Forces the use of Grep method
                    m, mdls      Forces the use of MacOS Quartz mdls
                    p, pdfinfo   Forces the use of PDFInfo
                    i, identify  Forces the use of ImageMagick's Identify
                    s, gs        Forces the use of Ghostscript (PS script)
 -i, --info <file>
             Prints <file> Paper Size information to screen and exits
 -e, --explode
             Explode (split) outuput PDF into many files (one per page)
 --range, --page-range <page-list>
             Defines the page range to be processed, using the -sPageList notation
             Read below for more information on valid page ranges
 -s, --scale <factor>
             Changes the scaling factor or forces mixed mode
             Defaults: 0.95 (scale mode) / Disabled (resize mode)
             MUST be a number bigger than zero
             Eg. -s 0.8 for 80% of the original size
 -r, --resize <paper>
             Triggers the Resize Paper Mode, disables auto-scaling of 0.95
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
                                   on a kind of "majority decision"
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
 --background-cmyk <"C M Y K">
             Creates a background with a CMYK color setting on PDF scaling
             Must be quoted into a single parameter as in "0.2 0.2 0.2 0.2"
             Each color parameter is a floating point percentage number (between 0 and 1)
 --background-rgb <"R G B">
             Creates a background with a RGB color setting on PDF scaling
             Must be quoted into a single parameter as in "100 100 200"
             RGB numbers are integers between 0 and 255 (255 122 50)
 --newpdf    Uses the -dNEWPDF flag in the GS Call (deprecated in new versions of GS)
 --dry-run, --simulate
             Just simulate execution. Will not run ghostscript
 --print-gs-call, --gs-call
             Print GS call to stdout. Will print at the very end between markers
 -p, --print-papers
             Prints Standard Paper info tables to screen and exits

Scaling Mode:
 - The default mode of operation is scaling mode with fixed paper
   size and scaling pre-set to 0.95
 - By not using the resize mode you are using scaling mode
 - Flip-Detection and Auto-Rotation are disabled in Scaling mode,
   you can use '-r source -s <scale>' to override.
 - Ghostscript placement is from bottom-left position. This means that
   a bottom-left placement has ZERO for both X and Y translations.

Resize Paper Mode:
 - Disables the default scaling factor! (0.95)
 - Changes the PDF Paper Size in points. Will fit-to-page

Mixed Mode:
 - In mixed mode both the -s option and -r option must be specified
 - The PDF will be first resized then scaled

Page Ranges:
 - Please refer to the Ghostscript manual on '-sPageList' for more info and examples.
 - May cause execution warnings from Ghostscript if the PDF refences pages that were
   removed. The output file should still be created, but with broken internal links.
 - Using a range with an inexistant page will raise a warning from Ghostscript and
   may also generate blank pages.
 - Single page number | ex: --range 2
 - Interval           | ex: --range 2-4
 - List of pages      | ex: --range 1,3,6
 - From page to end   | ex: --range 3-
 - odd/even specifier | ex: --range odd
 - odd/even range     | ex: --range even:1-4
 - mixed entries      | ex: --range 1,3-5,8-

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
 - Paper size can be set manually in Millimeters, Inches or Points
 - Custom paper definition MUST be quoted into a single parameter
 - Actual size is applied in points (mms and inches are transformed)
 - Measurements: mm, mms,  millimeters
                 pt, pts,  points
                 in, inch, inches
 Use: pdfScale.sh -r 'custom <measurement> <width> <height>'
 Ex:  pdfScale.sh -r 'custom mm 300 300'

Using Source Paper Size: (no-resizing)
 - Wildcard 'source' is used to keep paper size the same as the input
 - Useful to run Auto-Rotation without resizing
 - Eg. pdfScale.sh -r source ./input.pdf

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
 - For detailed paper types information, use: pdfScale.sh -p

Examples:
 pdfScale.sh myPdfFile.pdf
 pdfScale.sh -i '/home/My Folder/My PDF File.pdf'
 pdfScale.sh myPdfFile.pdf "My Scaled Pdf"
 pdfScale.sh -v -v myPdfFile.pdf
 pdfScale.sh -s 0.85 myPdfFile.pdf My\ Scaled\ Pdf.pdf
 pdfScale.sh -m pdfinfo -s 0.80 -v myPdfFile.pdf
 pdfScale.sh -v -v -m i -s 0.7 myPdfFile.pdf
 pdfScale.sh -r A4 myPdfFile.pdf
 pdfScale.sh -v -v -r "custom mm 252 356" -s 0.9 -f "../input file.pdf" "../my new pdf"
  
```  
  
## Standard Paper Tables
The `-p` parameter prints detailed paper types information
```
$ pdfscale -p
pdfscale v2.3.7

Paper Sizes Information

+-----------------------------------------------------------------+
| ISO STANDARD                                                    |
+-----------------------------------------------------------------+
| Name            | inchW | inchH |  mm W |  mm H | pts W | pts H |
+-----------------+-------+-------+-------+-------+-------+-------+
| a0              |  33.1 |  46.8 |   841 |  1189 |  2384 |  3370 |
| a1              |  23.4 |  33.1 |   594 |   841 |  1684 |  2384 |
| a2              |  16.5 |  23.4 |   420 |   594 |  1191 |  1684 |
| a3              |  11.7 |  16.5 |   297 |   420 |   842 |  1191 |
| a4              |   8.3 |  11.7 |   210 |   297 |   595 |   842 |
| a4small         |   8.3 |  11.7 |   210 |   297 |   595 |   842 |
| a5              |   5.8 |   8.3 |   148 |   210 |   420 |   595 |
| a6              |   4.1 |   5.8 |   105 |   148 |   297 |   420 |
| a7              |   2.9 |   4.1 |    74 |   105 |   210 |   297 |
| a8              |   2.1 |   2.9 |    52 |    74 |   148 |   210 |
| a9              |   1.5 |   2.1 |    37 |    52 |   105 |   148 |
| a10             |   1.0 |   1.5 |    26 |    37 |    73 |   105 |
| isob0           |  39.4 |  55.7 |  1000 |  1414 |  2835 |  4008 |
| isob1           |  27.8 |  39.4 |   707 |  1000 |  2004 |  2835 |
| isob2           |  19.7 |  27.8 |   500 |   707 |  1417 |  2004 |
| isob3           |  13.9 |  19.7 |   353 |   500 |  1001 |  1417 |
| isob4           |   9.8 |  13.9 |   250 |   353 |   709 |  1001 |
| isob5           |   6.9 |   9.8 |   176 |   250 |   499 |   709 |
| isob6           |   4.9 |   6.9 |   125 |   176 |   354 |   499 |
| c0              |  36.1 |  51.1 |   917 |  1297 |  2599 |  3677 |
| c1              |  25.5 |  36.1 |   648 |   917 |  1837 |  2599 |
| c2              |  18.0 |  25.5 |   458 |   648 |  1298 |  1837 |
| c3              |  12.8 |  18.0 |   324 |   458 |   918 |  1298 |
| c4              |   9.0 |  12.8 |   229 |   324 |   649 |   918 |
| c5              |   6.4 |   9.0 |   162 |   229 |   459 |   649 |
| c6              |   4.5 |   6.4 |   114 |   162 |   323 |   459 |
+-----------------+-------+-------+-------+-------+-------+-------+

+-----------------------------------------------------------------+
| US STANDARD                                                     |
+-----------------------------------------------------------------+
| Name            | inchW | inchH |  mm W |  mm H | pts W | pts H |
+-----------------+-------+-------+-------+-------+-------+-------+
| 11x17           |  11.0 |  17.0 |   279 |   432 |   792 |  1224 |
| ledger          |  17.0 |  11.0 |   432 |   279 |  1224 |   792 |
| legal           |   8.5 |  14.0 |   216 |   356 |   612 |  1008 |
| letter          |   8.5 |  11.0 |   216 |   279 |   612 |   792 |
| lettersmall     |   8.5 |  11.0 |   216 |   279 |   612 |   792 |
| archE           |  36.0 |  48.0 |   914 |  1219 |  2592 |  3456 |
| archD           |  24.0 |  36.0 |   610 |   914 |  1728 |  2592 |
| archC           |  18.0 |  24.0 |   457 |   610 |  1296 |  1728 |
| archB           |  12.0 |  18.0 |   305 |   457 |   864 |  1296 |
| archA           |   9.0 |  12.0 |   229 |   305 |   648 |   864 |
+-----------------+-------+-------+-------+-------+-------+-------+

+-----------------------------------------------------------------+
| JIS STANDARD *Aproximated Points                                |
+-----------------------------------------------------------------+
| Name            | inchW | inchH |  mm W |  mm H | pts W | pts H |
+-----------------+-------+-------+-------+-------+-------+-------+
| jisb0           |    NA |    NA |  1030 |  1456 |  2920 |  4127 |
| jisb1           |    NA |    NA |   728 |  1030 |  2064 |  2920 |
| jisb2           |    NA |    NA |   515 |   728 |  1460 |  2064 |
| jisb3           |    NA |    NA |   364 |   515 |  1032 |  1460 |
| jisb4           |    NA |    NA |   257 |   364 |   729 |  1032 |
| jisb5           |    NA |    NA |   182 |   257 |   516 |   729 |
| jisb6           |    NA |    NA |   128 |   182 |   363 |   516 |
+-----------------+-------+-------+-------+-------+-------+-------+

+-----------------------------------------------------------------+
| OTHERS                                                          |
+-----------------------------------------------------------------+
| Name            | inchW | inchH |  mm W |  mm H | pts W | pts H |
+-----------------+-------+-------+-------+-------+-------+-------+
| flsa            |   8.5 |  13.0 |   216 |   330 |   612 |   936 |
| flse            |   8.5 |  13.0 |   216 |   330 |   612 |   936 |
| halfletter      |   5.5 |   8.5 |   140 |   216 |   396 |   612 |
| hagaki          |   3.9 |   5.8 |   100 |   148 |   283 |   420 |
+-----------------+-------+-------+-------+-------+-------+-------+
```

## Dependencies  
The script uses `basename`, `grep`, `bc` and `gs` (ghostscript).   
You probably have everything installed already, except for ghostscript.   
Optional dependencies are `imagemagick`, `pdfinfo` and `mdls` (Mac).  
This app is focused in `Bash`, so it will probably not run in other shells.  
The script will need to see the dependencies on your `$PATH` variable.

##### apt-get
```
sudo apt-get install ghostscript bc
```
##### yum
```
sudo yum install ghostscript bc
```
##### homebrew MacOS
```
brew install ghostscript
```
##### Optionals
Page Size detection is by default in Adaptive Mode.  
It will try the following methods in sequence:   
 1. Try to get `/MediaBox` with `grep` (fastest)
 2. Failed AND MacOS ? Try `mdls`
 3. Failed ? Try `pdfinfo`
 4. Failed ? Try ImageMagick's `identify`
 5. Failed ? Try Ghostscript with a PS script
 6. Failed ? `Exit` with error message

The `grep` method will fail on PDFs without a `/MediaBox`.   
You may install any of the optionals to be used in that case.  

MacOS is fine using `mdls` if the metadata of the file is accurate.  
The metadata is generated automatically by the OS (Spotlight)

##### apt-get
```
sudo apt-get install imagemagick pdfinfo
```
##### yum
```
sudo yum install imagemagick pdfinfo
```
##### homebrew MacOS
```
brew install imagemagick xpdf
```
  
## Windows

- The script should work fine in cygwin.
- If you are using msys/git for windows, and the script exits with a 'file not found' error,
- try running `export MSYS_NO_PATHCONV=1`
- and `export MSYS2_ARG_CONV_EXCL="*"`
- and then running again.

## Clone using git
```
git clone https://github.com/tavinus/pdfScale.git
cd ./pdfScale
./pdfScale.sh --version
```
  
## Self-Install
Since `v2.3.0` *pdfScale* can install itself using the parameter `--install`.  
  
By default it will install to `/usr/local/bin/pdfscale`  
```
./pdfScale.sh --install
```
A custom location can be specified as a parameter.  
Should contain full path to executable file.  
```
./pdfScale.sh --install /opt/pdfscale/pdfscale
```
  
## Run installer using `curl` or `wget`
#### wget oneliners
```bash
# Normal install with prompts
wget -q -O /tmp/pdfScale.sh 'https://raw.githubusercontent.com/tavinus/pdfScale/master/pdfScale.sh' && bash /tmp/pdfScale.sh --install

# Automated install with --assume-yes
wget -q -O /tmp/pdfScale.sh 'https://raw.githubusercontent.com/tavinus/pdfScale/master/pdfScale.sh' && bash /tmp/pdfScale.sh --install --assume-yes

# To ignore SSL, use --no-check-certificate
wget --no-check-certificate -q -O /tmp/pdfScale.sh 'https://raw.githubusercontent.com/tavinus/pdfScale/master/pdfScale.sh' && bash /tmp/pdfScale.sh --install
```
#### curl oneliners
```bash
# Normal install with prompts
curl -s -o /tmp/pdfScale.sh 'https://raw.githubusercontent.com/tavinus/pdfScale/master/pdfScale.sh' && bash /tmp/pdfScale.sh --install

# Automated install with --assume-yes
curl -s -o /tmp/pdfScale.sh 'https://raw.githubusercontent.com/tavinus/pdfScale/master/pdfScale.sh' && bash /tmp/pdfScale.sh --install --assume-yes

# To ignore SSL, use --insecure
curl --insecure -s -o /tmp/pdfScale.sh 'https://raw.githubusercontent.com/tavinus/pdfScale/master/pdfScale.sh' && bash /tmp/pdfScale.sh --install
```
#### Remove /tmp/pdfScale.sh after done
```bash
rm /tmp/pdfScale.sh
```
  
## Install with `make`
The `make` installer will name the executable as `pdfscale` with no uppercase chars and without the `.sh` extension.  

If you have `make` installed you can use it to install to `/usr/local/bin/pdfscale` with:  
```
sudo make install
```
To remove the installation use:  
```
sudo make uninstall
```   
  
## Self-Upgrade
Since `v2.3.0` *pdfScale* can upgrade itself using the parameter `--upgrade`.  
  
It will try to get the master branch and update itself in-place.    
```
pdfscale --upgrade
```
More info on the [Self-Upgrade Wiki](https://github.com/tavinus/pdfScale/wiki/Self-Upgrade)  
  
---
  
# Links
#### [ma.juii.net - The History](https://ma.juii.net/blog/scale-page-content-of-pdf-files)
#### [SO - Scale pdf to add border for printing full size pages](https://stackoverflow.com/questions/18343813/scale-pdf-to-add-border-for-printing-full-size-pages/)
#### [MichaelJCole original gist - pdfScale.sh](https://gist.github.com/MichaelJCole/86e4968dbfc13256228a)
