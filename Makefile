# Vendor policy: pit.js/lit-html.js come from the supplied arui tree; KaTeX is 0.18.5.
PANDOC ?= pandoc
PYTHON ?= python3

SITE_TITLE := Arcie's Studio
SRC := $(wildcard src/*.md)
PAGES := $(patsubst src/%.md,static/%.html,$(SRC))
MEDIA := $(wildcard src/media/*)

PANDOC_FLAGS := \
	--from=markdown \
	--to=html5 \
	--standalone \
	--section-divs \
	--wrap=none \
	--syntax-highlighting=breezeDark \
	--template=gen.html \
	--lua-filter=gen.lua \
	-M site-title="$(SITE_TITLE)"

all: index.html $(PAGES) static/media/.stamp

index.html: $(SRC) gen.html gen.lua
	$(PANDOC) $(SRC) $(PANDOC_FLAGS) \
		-M page-kind=index \
		-M root=. \
		-M title="$(SITE_TITLE)" \
		-M summary="Shift the world by writing." \
		-o $@

static/%.html: src/%.md gen.html gen.lua
	@mkdir -p static
	$(PANDOC) $< $(PANDOC_FLAGS) \
		-M page-kind=article \
		-M root=.. \
		--toc --toc-depth=3 \
		-o $@

static/media/.stamp: $(MEDIA)
	@mkdir -p static/media
	@rm -rf static/media/*
	@cp -R src/media/. static/media/
	@touch $@

serve: all
	$(PYTHON) -m http.server 8000

clean:
	rm -f index.html
	rm -rf static

.PHONY: all serve clean
