###
### generic GNU make Makefile for .tex -> .pdf.
### ransford at cs.washington.edu
###   http://github.com/ransford/pdflatex-makefile
### edited by Emanuel Regnath, 2016
###
### Recommended usage:
###   1. $ make pdf          (make the pdf)
###   2. $ make snapshot     (pass around a draft...)
###   2. $ make distill      (submit the camera-ready version with embedded fonts)
###

###################################################################################################
# #  Own Changes
###################################################################################################


## Name of the target file, minus .pdf: e.g., TARGET=mypaper causes this
## Makefile to turn mypaper.tex into mypaper.pdf.
TARGET=main

# output directory
OUT_DIR=build

# include path (column separated folders, e.g. lib:res)
INCPATH = inc:lib:res:content



# compiler
# TEXCMD	?= pdflatex
TEXCMD  	?= lualatex 
TEXFLAGS    ?= -halt-on-error -file-line-error -output-directory=$(OUT_DIR) -interaction=nonstopmode
BIBERCMD	?= biber --quiet 
BIBTEXCMD	?= bibtex -terse
MAKEGLOSSARIES ?= makeglossaries -d $(OUT_DIR)

## Action for 'make view'
PDFVIEWER	?= xdg-open   # only "open" if on Darwin 




###################################################################################################
# #  Don't edit below this Line!!!
###################################################################################################



# search for additional tex files
export TEXINPUTS+=:${INCPATH}:${OUT_DIR}//


# define output filter
# ERRFILTER_AUX	:= 2>&1 | egrep --color -A5 '^! \w+ Error:|.*:[0-9]*:.*|^l\.[0-9]* |\w+ Warning:'
ERRFILTER_AUX	:= 2>&1 | egrep --color -A3 '^! \w+ Error:' || true
ERRFILTER	:= 2>&1 | egrep --color -A3 '^! \w+ Error:|.*:[0-9]*:.*|^l\.[0-9]* |\w+ Warning:'

# finalize command line
PDFLATEX	= ${TEXCMD} ${TEXFLAGS}

TARGETS   += $(TARGET)
TEXTARGETS = $(TARGETS:=.tex)
# PDFTARGETS = $(TARGETS:=.pdf)
PDFTARGETS = $(patsubst %, $(OUT_DIR)/%.pdf, $(TARGETS))
AUXFILES   = $(patsubst %, $(OUT_DIR)/%.aux, $(TARGETS))
LOGFILES   = $(patsubst %, $(OUT_DIR)/%.log, $(TARGETS))

## If $(TARGET).tex refers to .bib files like \bibliography{foo,bar}, then
## $(BIBTEXFILES) will contain foo.bib and bar.bib, and both files will be added as
## dependencies to $(PDFTARGETS).
## Effect: updating a .bib file will trigger re-typesetting.
BIBTEXFILES += $(patsubst %,%.bib,\
		$(shell grep '^[^%]*\\bibliography{' $(TEXTARGETS) | \
			grep -o '\\bibliography{[^}]\+}' | \
			sed -e 's/^[^%]*\\bibliography{\([^}]*\)}.*/\1/' \
			    -e 's/, */ /g'))


## If $(TARGET).tex refers to .bib files like \addbibresource{foo.bib}, then
## $(BIBLATEXFILES) will contain foo.bib and  will be added as dependencies to $(PDFTARGETS).
## Effect: updating a .bib file will trigger re-typesetting.
BIBLATEXFILES += $(shell \
			grep '^[^%]*\\addbibresource{' $(TEXTARGETS) | \
			grep -o '\\addbibresource{[^}]\+}' | \
			sed -e 's/^[^%]*\\addbibresource{\([^}]*\)}.*/\1/' \
			    -e 's/, */ /g')

## Add \input'ed or \include'd files to $(PDFTARGETS) dependencies; add
## .tex extensions.
INCLUDEDTEX = $(shell grep '^[^%]*\\\(input\|include\){' $(TEXTARGETS) | \
			grep -o '\\\(input\|include\){[^}]\+}' | \
			sed -e 's/^.*{\([^}]*\)}.*/\1/' \
			    -e 's/\.tex$$//' -e 's/$$/.tex/')


# AUXFILES += $(patsubst %, $(OUT_DIR)/%.aux, $(notdir $(INCLUDEDTEX)))

all: init pdf

init:
# 	@mkdir -p ${OUT_DIR}/inc
	@mkdir -p ${OUT_DIR}
	@echo "TARGETS:  $(PDFTARGETS)"
	@echo "INCLUDED: $(INCLUDEDTEX)"
	@echo "AUXS: $(AUXFILES)"
	@echo "BIBTEX: $(BIBTEXFILES)"
	@echo "BIBLATEX: $(BIBLATEXFILES)"
	@echo "BIBDEPS: $(BIBDEPS)"
	@ln -s $(patsubst %, ../%, $(TEXTARGETS)) ${OUT_DIR}/ || true



direct:
	lualatex -output-directory=$(OUT_DIR) $(TARGET).tex
	biber -output-directory=$(OUT_DIR) $(TARGET)
	lualatex -output-directory=$(OUT_DIR) $(TARGET).tex
	

finish:
	@cp ${OUT_DIR}/$(TARGET).pdf ./$(TARGET).pdf


# .PHONY names all targets that aren't filenames
.PHONY: all clean pdf view snapshot distill distclean

pdf: init $(PDFTARGETS) finish

view: $(PDFTARGETS)
	$(PDFVIEWER) $(PDFTARGETS)


# to generate aux but not pdf from pdflatex, use -draftmode
$(OUT_DIR)/%.aux: %.tex 
	@echo "Running $(PDFLATEX)"
	$(PDFLATEX) $* $(ERRFILTER_AUX)

# introduce BibTeX dependency if we found a \bibliography
ifneq ($(strip $(BIBTEXFILES)),)
BIBDEPS = %.bbl
$(OUT_DIR)/%.bbl: $(OUT_DIR)/%.aux $(BIBTEXFILES)
# $(OUT_DIR)/%.bbl: $(BIBTEXFILES)
	$(BIBTEXCMD) $(OUT_DIR)/$*
endif


# introduce BibLaTeX/Biber dependency if we found a \addbibresource
# ifneq ($(strip $(BIBLATEXFILES)),)
# BIBDEPS = %.bbl
# %.bbl: $(BIBLATEXFILES)
# 	$(BIBERCMD) $*
# endif


# introduce makeglossaries dependency if we found \printglossary/ies
HAS_GLOSSARIES = $(shell \
		grep '^[^%]*\\printglossar\(ies\|y\)' $(TEXTARGETS) $(INCLUDEDTEX) && \
		echo HAS_GLOSSARIES)
ifneq ($(HAS_GLOSSARIES),)
GLSDEPS = %.gls
%.gls: %.aux
	$(MAKEGLOSSARIES) $(TARGETS)
endif

$(PDFTARGETS): %.pdf: %.tex $(AUXFILES) $(GLSDEPS) $(BIBDEPS) 
	$(PDFLATEX) $* $(ERRFILTER)
	@echo "TARGET:"$*
ifneq ($(strip $(BIBTEXFILES)),)
	@if egrep -q "undefined (references|citations)" $*.log; then \
		$(BIBTEXCMD) $* && $(PDFLATEX) $* $(ERRFILTER_AUX); fi
endif
ifneq ($(strip $(BIBLATEXFILES)),)
	@echo "LOGFILE: "$*.log
	@if egrep -q "Please (re)run Biber on the file:" $*.log; then \
		$(BIBERCMD) $*; fi
endif
	@while grep -q "Rerun to\|Please rerun LaTeX." $*.log; do \
		$(PDFLATEX) $* $(ERRFILTER_AUX); done



%.pdf : %.svg
	@echo "======= Converting SVG to PDF: $< ======="
	@inkscape --without-gui --file=$< --export-pdf=$@ #--export-text-to-path


# DRAFTS := $(PDFTARGETS:.pdf=-$(REVISION).pdf)
# $(DRAFTS): %-$(REVISION).pdf: %.pdf
# 	cp $< $@
# snapshot: $(DRAFTS)

# %.distilled.pdf: %.pdf
# 	gs -q -dSAFER -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=$@ \
# 		-dCompatibilityLevel=1.5 -dPDFSETTINGS=/prepress -c .setpdfwrite -f $<
# 	exiftool -overwrite_original -Title="" -Creator="" -CreatorTool="" $@

# distill: $(PDFTARGETS:.pdf=.distilled.pdf)

# distclean: clean
# 	$(RM) $(PDFTARGETS) $(PDFTARGETS:.pdf=.distilled.pdf) $(EXTRADISTCLEAN)

clean:
	$(RM) -r $(OUT_DIR)/inc
	$(RM) $(OUT_DIR)/*
	$(RM) $(foreach T,$(TARGETS), \
		$(T).bbl $(T).bcf $(T).bit $(T).blg \
		$(T)-blx.bib $(T).brf $(T).glg $(T).glo \
		$(T).gls $(T).glsdefs $(T).glx \ $(T).gxg \
		$(T).acn $(T).acr $(T).alg $(T).sym $(T).sbl $(T).ter $(T).tms\
		$(T).gxs $(T).idx $(T).ilg $(T).ind \
		$(T).ist $(T).loa $(T).lof $(T).lol \
		$(T).lot $(T).maf $(T).mtc $(T).nav \
		$(T).out $(T).pag $(T).run.xml $(T).snm \
		$(T).svn $(T).tdo $(T).tns $(T).toc \
		$(T).vtc $(T).url) \
		$(AUXFILES) $(LOGFILES) \
		$(EXTRACLEAN)