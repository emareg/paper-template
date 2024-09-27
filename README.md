# paper-template
Universal latex paper template for IEEE, ACM, LNCS

## Usage

1. Edit `main.tex` and adjust metadata
2. Edit content files in `/content`
3. Add your references to `res/bib/references.bib`
4. Compile

For compilation use two runs of pdflatex in combination with bibtex:

```bash
pdflatex main.tex
bibtex main.tex
pdflatex main.tex
```


