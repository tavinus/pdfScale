# pdfScale.sh
Bash Script to scale PDFs from the command line.  
Uses ghostscript to create a scaled version of the pdf input.  
The "paper" size does not change, just the elements are resized.   

## Dependencies  
The script uses `basename`, `cat`, `grep`, `bc`, `head` and `gs` (ghostscript).   
You probably have everything installed already, except for ghostscript.   
Optional dependencies are `imagemagick`, `pdfinfo` and `mdls` (Mac).

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
From version 1.4.x I decided to create an adaptive method of getting the pagesize. It will try different methods if the previous one fails. People can also force a specific mode of operation with the `-m` parameter.   
 
The order of operation is as follows:
 1. Try to get `/MediaBox` with cat + grep
 2. Failed AND MacOs ? Try mdls
 3. Failed AND NOT MacOS ? Try pdfinfo
 4. Failed ? Try ImageMagick's identify
 5. Failed ? Exit with error message
 
The postscript/ghostscript method was removed until I can write a PS script that gets the page size.   
 
## Help info
```
$ pdfscale -h
pdfscale v1.4.5

Usage: pdfscale [-v] [-s <factor>] [-i|-c] <inFile.pdf> [outfile.pdf]
       pdfscale -h
       pdfscale -V

Parameters:
 -v          Verbose mode, prints extra information
             Use twice for even more information
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
 -m <mode>   Force a mode of page size detection. 
             Will disable the Adaptive Mode.
 -c          Use cat + grep to get page size, 
             instead of postscript method
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
 - Page size detection will try different modes until it gets
   a page size, or you can force a mode with -m 'mode'
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
 pdfscale myPdfFile.pdf
 pdfscale myPdfFile.pdf myScaledPdf
 pdfscale -v -v myPdfFile.pdf
 pdfscale -s 0.85 myPdfFile.pdf myScaledPdf.pdf
 pdfscale -m pdfinfo -s 0.80 -v myPdfFile.pdf
 pdfscale -v -v -s 0.7 myPdfFile.pdf
 pdfscale -h
```

## Example runs
```
$ ./pdfScale.sh -v -m i ../00-test-xml2dacte.pdf 
pdfScale.sh v1.4.5 - Verbose execution
Checking for ghostscript and bcmath
Checking for imagemagick's identify
  Scale factor: 0.95
    Input file: ../00-test-xml2dacte.pdf
   Output file: ../00-test-xml2dacte.SCALED.pdf
 Adaptive mode: Disabled
        Method: ImageMagick's Identify
         Width: 595 postscript-points
        Height: 842 postscript-points
 Translation X: 15.657425
 Translation Y: 22.157230
```
```
$ ./pdfScale.sh -v -v ../input-nup.pdf 
2017-02-22:03:09:59 | pdfScale.sh v1.4.5 - Verbose execution
2017-02-22:03:09:59 | Checking for ghostscript and bcmath
2017-02-22:03:09:59 |   Scale factor: 0.95
2017-02-22:03:09:59 |     Input file: ../input-nup.pdf
2017-02-22:03:09:59 |    Output file: ../input-nup.SCALED.pdf
2017-02-22:03:09:59 |  Adaptive mode: Enabled
2017-02-22:03:09:59 |         Method: Cat + Grep
2017-02-22:03:09:59 |                 Failed
2017-02-22:03:09:59 |         Method: Mac Quartz mdls
2017-02-22:03:09:59 |          Width: 595 postscript-points
2017-02-22:03:09:59 |         Height: 842 postscript-points
2017-02-22:03:09:59 |  Translation X: 15.657425
2017-02-22:03:09:59 |  Translation Y: 22.157230
```

## System Install
Please note that the system installer will name the executable as `pdfscale` with no uppercase chars and without the `.sh` extension.  
  
If you have `make` installed you can use it to install to `usr/local/bin/pdfscale` with:  
```
sudo make install
```  
  
To remove the installation use:  
```
sudo make uninstall
```
