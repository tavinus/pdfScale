# pdfScale.sh
Bash Script to scale and resize PDFs from the command line.  
Uses ghostscript to create a scaled and or resized version of the pdf input.  
  
In `scaling mode`, the PDF paper size does not change, just the elements are scaled.  
In `resize mode`, the PDF paper will be changed and fit-to-page will be applied.  
In `mixed mode`, the PDF will first be `resized` then `scaled` with two Ghostscript calls.  
A temporary file is used in `mixed mode`, at the target location.

## Dependencies  
The script uses `basename`, `cat`, `grep`, `bc`, `head` and `gs` (ghostscript).   
You probably have everything installed already, except for ghostscript.   
Optional dependencies are `imagemagick`, `pdfinfo` and `mdls` (Mac).  
This app is focused in `Bash`, so it will probably not run on other Shells.  

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
 1. Try to get `/MediaBox` with `cat` + `grep`
 2. Failed AND MacOS ? Try `mdls`
 3. Failed ? Try `pdfinfo`
 4. Failed ? Try ImageMagick's `identify`
 5. Failed ? `Exit` with error message
 
The `cat`+`grep` method will fail on PDFs without a `/MediaBox`.   
You may install any of the optionals to be used in that case.  
  
MacOS is fine using `mdls` if the metadata of the file is accurate.  
The metadata is generated automatically by the OS (SpolLight)
  
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

 
## Help info
```
$ pdfscale -h
pdfscale v2.0.0

Usage: pdfscale [-v] [-s <factor>] [-m <mode>] [-r <paper>] <inFile.pdf> [outfile.pdf]
       pdfscale -p
       pdfscale -h
       pdfscale -V

Parameters:
 -v          Verbose mode, prints extra information
             Use twice for timestamp
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
 -m <mode>   Page size Detection mode 
             May disable the Adaptive Mode
 -s <factor> Changes the scaling factor or forces scaling
             Defaults: 0.95 / no scaling (resize mode)
             MUST be a number bigger than zero
             Eg. -s 0.8 for 80% of the original size
 -r <paper>  Triggers the Resize Paper Mode
             Resize PDF paper proportionally
             Must be a valid Ghostscript paper name
 -p          Prints Ghostscript paper info tables to screen

Scaling Mode:
The default mode of operation is scaling mode with fixed paper
size and scaling pre-set to 0.95. By not using the resize mode
you are using scaling mode.

Resize Paper Mode:
Disables the default scaling factor! (0.95)
Alternative mode of operation to change the PDF paper
proportionally. Will fit-to-page.

Mixed Mode:
In mixed mode both the -s option and -r option must be specified.
The PDF will be both scaled and have the paper type changed.

Output filename:
The output filename is optional. If no file name is passed
the output file will have the same name/destination of the
input file with added suffixes:
  .SCALED.pdf             is added to scaled files
  .<PAPERSIZE>.pdf        is added to resized files
  .<PAPERSIZE>.SCALED.pdf is added in mixed mode

Page Detection Modes:
 a, adaptive  Default mode, tries all the methods below
 c, cat+grep  Forces the use of the cat + grep method
 m, mdls      Forces the use of MacOS Quartz mdls
 p, pdfinfo   Forces the use of PDFInfo
 i, identify  Forces the use of ImageMagick's Identify

Valid Ghostscript Paper Names:
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

Notes:
 - Adaptive Page size detection will try different modes until
   it gets a page size. You can force a mode with -m 'mode'.
 - Options must be passed before the file names to be parsed.
 - Having the extension .pdf on the output file name is optional,
   it will be added if not present.
 - File and folder names with spaces should be quoted or escaped.
 - The scaling is centered and using a scale bigger than 1 may
   result on cropping parts of the pdf.

Examples:
 pdfscale myPdfFile.pdf
 pdfscale myPdfFile.pdf myScaledPdf
 pdfscale -v -v myPdfFile.pdf
 pdfscale -s 0.85 myPdfFile.pdf myScaledPdf.pdf
 pdfscale -m pdfinfo -s 0.80 -v myPdfFile.pdf
 pdfscale -v -v -m i -s 0.7 myPdfFile.pdf
 pdfscale -h
```

## Example runs
```
$ pdfscale -v -r a0 -s 1.05 ../mixsync\ manual\ v1-2-3.pdf 
pdfscale v2.0.0 - Verbose Execution
Checking for ghostscript and bcmath
    Input file: ../mixsync manual v1-2-3.pdf
   Output file: ../mixsync manual v1-2-3.A0.SCALED.pdf
 Get Page Size: Adaptive Enabled
        Method: Cat + Grep
   Mixed Tasks: Resize & Scale
  Scale factor: 1.05
  Source Width: 842 postscript-points
 Source Height: 595 postscript-points
   Flip Detect: Wrong orientation!
                Inverting Width <-> Height
   Resizing to: A0 ( 3370 x 2384 )
     New Width: 3370 postscript-points
    New Height: 2384 postscript-points
 Translation X: -80.236330
 Translation Y: -56.760656
```
```
$ pdfscale -v -v -s 0.9 ../input-nup.pdf "../my glorius PDF" 
pdfscale v2.0.0 - Verbose Execution
2017-05-13:20:22:18 | Checking for ghostscript and bcmath
2017-05-13:20:22:18 |     Input file: ../input-nup.pdf
2017-05-13:20:22:18 |    Output file: ../my glorius PDF.pdf
2017-05-13:20:22:18 |  Get Page Size: Adaptive Enabled
2017-05-13:20:22:18 |         Method: Cat + Grep
2017-05-13:20:22:18 |                 Failed
2017-05-13:20:22:18 |         Method: Mac Quartz mdls
2017-05-13:20:22:18 |    Single Task: Scale PDF Contents
2017-05-13:20:22:18 |   Scale factor: 0.9 (manual)
2017-05-13:20:22:18 |   Source Width: 842 postscript-points
2017-05-13:20:22:18 |  Source Height: 595 postscript-points
2017-05-13:20:22:18 |  Translation X: 46.777310
2017-05-13:20:22:18 |  Translation Y: 33.055225
```
```
$ pdfscale -v -r a2 "../mixsync manual v1-2-3.pdf" 
pdfscale v2.0.0 - Verbose Execution
Checking for ghostscript and bcmath
    Input file: ../mixsync manual v1-2-3.pdf
   Output file: ../mixsync manual v1-2-3.A2.pdf
 Get Page Size: Adaptive Enabled
        Method: Cat + Grep
   Single Task: Resize PDF Paper
  Scale factor: Disabled (resize only)
  Source Width: 842 postscript-points
 Source Height: 595 postscript-points
   Flip Detect: Wrong orientation!
                Inverting Width <-> Height
   Resizing to: A2 ( 1684 x 1191 )
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
