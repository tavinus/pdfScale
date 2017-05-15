# pdfScale 2
Bash Script to ***scale*** and/or ***resize*** PDFs from the command line.  
Uses ghostscript (`gs`) to create a scaled and/or resized version of the pdf input.  
  
In `scaling mode`, the PDF paper size does not change, just the elements are scaled.  
In `resize mode`, the PDF paper will be changed and fit-to-page will be applied.  
In `mixed mode`, the PDF will first be `resized` then `scaled` with two Ghostscript calls.  
A temporary file is used in `mixed mode`, at the target location.  

## Example Runs
### Better than explaining is showing it:
#### Checking File Information
```
$ ./pdfScale.sh -i ../input-nup.pdf 
pdfScale.sh v2.0.0 - Paper Sizes
------------+-----------------------------
       File | input-nup.pdf
 Paper Type | A4 Landscape
------------+-----------------------------
            |    WIDTH x HEIGHT
     Points |      842 x 595     
 Milimeters |      297 x 210     
     Inches |     11.7 x 8.3
```
#### Scale by 0.95 (-5%)
```
$ pdfscale -v ../input-nup.pdf
pdfscale v2.0.2 - Verbose Execution
   Single Task: Scale PDF Contents
    Input File: ../input-nup.pdf
   Output File: ../input-nup.SCALED.pdf
 Get Page Size: Adaptive Enabled
        Method: Grep
                Failed
        Method: Mac Quartz mdls
  Source Width: 842 postscript-points
 Source Height: 595 postscript-points
  Scale Factor: 0.95 (auto)
 Translation X: 22.157230
 Translation Y: 15.657425
   Run Scaling: -5 %
  Final Status: File created successfully
```
#### Resize to A0 and Scale by 1.05 (+5%)
```
$ pdfscale -v -r a0 -s 1.05 ../mixsync\ manual\ v1-2-3.pdf
pdfscale v2.0.0 - Verbose Execution
   Mixed Tasks: Resize & Scale
    Input File: ../mixsync manual v1-2-3.pdf
   Output File: ../mixsync manual v1-2-3.A0.SCALED.pdf
 Get Page Size: Adaptive Enabled
        Method: Grep
  Source Width: 842 postscript-points
 Source Height: 595 postscript-points
   Auto Rotate: PageByPage
   Flip Detect: Wrong orientation detected!
                Inverting Width <-> Height
  Run Resizing: A0 ( 3370 x 2384 ) pts
     New Width: 3370 postscript-points
    New Height: 2384 postscript-points
  Scale Factor: 1.05
 Translation X: -80.236330
 Translation Y: -56.760656
   Run Scaling: 5 %
  Final Status: File created successfully
```
#### Resize to A2 and disables Auto-Rotation
```
$ pdfscale -v -r A2 -a none ../input.pdf
pdfscale v2.0.0 - Verbose Execution
   Single Task: Resize PDF Paper
    Input File: ../input.pdf
   Output File: ../input.A2.pdf
 Get Page Size: Adaptive Enabled
        Method: Grep
  Source Width: 595 postscript-points
 Source Height: 842 postscript-points
  Scale Factor: Disabled (resize only)
   Auto Rotate: None
   Flip Detect: No change needed
  Run Resizing: A2 ( 1191 x 1684 ) pts
  Final Status: File created successfully
```
#### Resize to custom 200x200 mm, disable Flip-Detection and Scale by 0.95 (-5%)
```
$ pdfscale -v -v -r 'custom mm 200 200' -f disable -s 0.95 ../mixsync\ manual\ v1-2-3.pdf
2017-05-15:08:48:06 | pdfscale v2.0.2 - Verbose Execution
2017-05-15:08:48:06 |    Mixed Tasks: Resize & Scale
2017-05-15:08:48:06 |     Input File: ../mixsync manual v1-2-3.pdf
2017-05-15:08:48:06 |    Output File: ../mixsync manual v1-2-3.CUSTOM.SCALED.pdf
2017-05-15:08:48:06 |  Get Page Size: Adaptive Enabled
2017-05-15:08:48:06 |         Method: Grep
2017-05-15:08:48:06 |   Source Width: 842 postscript-points
2017-05-15:08:48:06 |  Source Height: 595 postscript-points
2017-05-15:08:48:06 |    Auto Rotate: PageByPage
2017-05-15:08:48:06 |    Flip Detect: Disabled
2017-05-15:08:48:06 |   Run Resizing: CUSTOM ( 567 x 567 ) pts
2017-05-15:08:48:06 |      New Width: 567 postscript-points
2017-05-15:08:48:06 |     New Height: 567 postscript-points
2017-05-15:08:48:06 |   Scale Factor: 0.95
2017-05-15:08:48:06 |  Translation X: 14.920605
2017-05-15:08:48:06 |  Translation Y: 14.920605
2017-05-15:08:48:06 |    Run Scaling: -5 %
2017-05-15:08:48:07 |   Final Status: File created successfully
```

## Help info
```
$ ./pdfScale.sh -h
pdfScale.sh v2.0.0

Usage: pdfScale.sh <inFile.pdf>
       pdfScale.sh -i <inFile.pdf>
       pdfScale.sh [-v] [-s <factor>] [-m <page-detection>] <inFile.pdf> [outfile.pdf]
       pdfScale.sh [-v] [-r <paper>] [-f <flip-detection>] [-a <auto-rotation>] <inFile.pdf> [outfile.pdf]
       pdfScale.sh -p
       pdfScale.sh -h
       pdfScale.sh -V

Parameters:
 -v          Verbose mode, prints extra information
             Use twice for timestamp
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
 -m <mode>   Page size Detection mode 
             May disable the Adaptive Mode
 -i <file>   Prints <file> Page Size information to screen and exits
 -s <factor> Changes the scaling factor or forces scaling
             Defaults: 0.95 / no scaling (resize mode)
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
                                    on a kind of "majority decision"
                    n, none       - retains orientation of each page
 -p          Prints Ghostscript paper info tables to screen

Scaling Mode:
 The default mode of operation is scaling mode with fixed paper
 size and scaling pre-set to 0.95. By not using the resize mode
 you are using scaling mode. Flip-Detection and Auto-Rotation are
 disabled in Scaling mode.

Resize Paper Mode:
 Disables the default scaling factor! (0.95)
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
 Paper size can be set manually in Milimeters, Inches or Points.
 Use: pdfScale.sh -r 'custom <measurement> <width> <height>'
 Ex:  pdfScale.sh -r 'custom mm 300 300'
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

## GhostScript Paper Tables
The `-p` parameter prints detailed paper types information
```
$ ./pdfScale.sh -p
pdfScale.sh v2.0.0

Valid Ghostscript Paper Sizes accepted

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
 5. Failed ? `Exit` with error message
 
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

## System Install
The installer will name the executable as `pdfscale` with no uppercase chars and without the `.sh` extension.  
  
If you have `make` installed you can use it to install to `/usr/local/bin/pdfscale` with:  
```
sudo make install
```  
  
To remove the installation use:  
```
sudo make uninstall
```
