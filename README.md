# pdfScale.sh
Bash Script to scale PDFs from the command line.  
Uses ghostscript to create a scaled version of the pdf input.  
The "paper" size does not change, just the elements are resized.   
#####Does not require ImageMagick anymore!  

## Dependencies  
The script uses `basename`, `cat`, `grep`, `bc` and `gs` (ghostscript)  
You probably have everything already, except for ghostscript  

##### apt-get
`sudo apt-get install ghostscript bc`
##### yum
`sudo yum install ghostscript bc`
##### homebrew MacOS
`brew install ghostscript`

## Help info
```
$ pdfscale -h
pdfscale v1.0.8

Usage: pdfscale [-v] [-s <factor>] <inFile.pdf> [outfile.pdf]
       pdfscale -h
       pdfscale -V

Parameters:
 -v          Verbose mode, prints extra information
             Use twice for even more information
 -h          Print this help to screen and exits
 -V          Prints version to screen and exits
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
 pdfscale myPdfFile.pdf
 pdfscale myPdfFile.pdf myScaledPdf
 pdfscale -v -v myPdfFile.pdf
 pdfscale -s 0.85 myPdfFile.pdf myScaledPdf.pdf
 pdfscale -v -v -s 0.7 myPdfFile.pdf
 pdfscale -h
```
## System Install
Please note that the system installer will name the executable as `pdfscale` with no uppercase chars and without the `.sh` extension.  
  
If you have `make` installed you can use it to install to `usr/local/bin/pdfscale` with:  
`sudo make install`  
  
To remove the installation use:  
`sudo make uninstall`  
