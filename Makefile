# Installs to /usr/local/bin
# Change variables to adjust locations
#
# Jul 10 2016 - Gustavo Neves

IDIR=/usr/local/bin
IFILE=$(IDIR)/pdfscale

all:

install:
	cp pdfScale.sh $(IFILE)
	chmod 755 $(IFILE)

uninstall:
	rm -f $(IFILE)
