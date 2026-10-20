# Build the workshop Beamer deck
# Prefers system TeX; falls back to local TinyTeX under .tools/

PDF = presentation.pdf
TEX = presentation.tex
TINYTEX_BIN = $(CURDIR)/.tools/.TinyTeX/bin/x86_64-linux

.PHONY: all clean

all: $(PDF)

$(PDF): $(TEX)
	@if command -v pdflatex >/dev/null 2>&1 && kpsewhich beamer.cls >/dev/null 2>&1; then \
	  PDFLATEX=pdflatex; \
	elif [ -x "$(TINYTEX_BIN)/pdflatex" ]; then \
	  export PATH="$(TINYTEX_BIN):$$PATH"; \
	  PDFLATEX=pdflatex; \
	else \
	  echo "ERROR: pdflatex/beamer not found. Install TeX Live or keep .tools/.TinyTeX"; \
	  exit 1; \
	fi; \
	$$PDFLATEX -interaction=nonstopmode $(TEX); \
	$$PDFLATEX -interaction=nonstopmode $(TEX)

clean:
	rm -f *.aux *.log *.nav *.out *.snm *.toc *.vrb $(PDF)
