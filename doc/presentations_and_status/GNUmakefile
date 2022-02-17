####################################
# Global Variables.

# Things we want to know how to build.
PRODUCTS = CetmodulesHighlights-2021-02-23.pdf \
	CetmodulesHighlights-2021-02-10.pdf

# All PDFs should be made portable, with subsetted fonts.
PORTABLE_PDF = 1

# Show the command lines used.
VERBOSE = 1

# Don't show command output or error.
# QUIET = 2
####################################

####################################
# Use doc.mk to produce our documents.
ifneq (,$(SSDDOC_INC))
  ddir = $(SSDDOC_INC)
else
  ddir = ../../../cet-is/ssddoc/include
endif

include $(ddir)/doc.mk

# Check we have the version we need of doc.mk.
verified_doc_mk_version := $(call require_doc_mk_version,0.1.0)
####################################

####################################
# LaTeX-specific environment variables.

# LaTeXMK looks in TEXINPUTS for e.g. .bst files, but doesn't know how
# to look in recursive paths (//), so we add the specific directory for
# woc.bst to the front of TEXINPUTS.
export TEXINPUTS=$(DOC_MK_DIR)web-conf/:$(DOC_MK_DIR)/:
export BSTINPUTS=$(DOC_MK_DIR)web-conf/:
####################################

####################################
# Target-specific variables and additive overrides.

# Identify targets requiring beamer.
$(call targets_without,-paper): override PANDOC_BEAMER = YES

# Regenerate and clean up .bbl files.
# override LATEXMK_EXTRA_OPTS += -bibtex

# Make Pandoc more verbose.
# override PANDOC_EXTRA_OPTS += --verbose
####################################
