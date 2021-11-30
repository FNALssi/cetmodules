#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# install_headers()
#
#   Install headers scripts under
#     ${${CETMODULES_CURRENT_PROJECT_NAME}_INCLUDE_DIR}[/${CETMODULES_CURRENT_PROJECT_NAME}]
#
# Usage: install_headers([USE_(PRODUCT|PROJECT)_NAME]
#                        [SUBDIRNAME <subdir>] LIST ...)
#        install_headers([USE_(PRODUCT|PROJECT)_NAME]
#                        [SUBDIRNAME <subdir>] [BASENAME_EXCLUDES ...]
#                        [EXCLUDES ...] [EXTRAS ...] [SUBDIRS ...])
#
# See CetInstall.cmake for full usage description.
#
# Recognized filename extensions:
#   .h .hh .H .hpp .hxx .icc .tcc
#
# The ROOT dictionary header classes.h is usually excluded as a
# build-only item. If you specifically want it, add it to EXTRAS.
#
# USE_PRODUCT_NAME (deprecated) and USE_PROJECT_NAME will append a
# directory ${CETMODULES_CURRENT_PROJECT_NAME} to
# ${${CETMODULES_CURRENT_PROJECT_NAME}_INCLUDE_DIR}/<subdir>. In any case, the current
# package subdirectory will be appended to the result followed by any
# SUBDIRS for files found therein.
#
# Build directories will be searched for suitable files.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetInstall)
include(CetPackagePath)

function(install_headers)
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  cmake_parse_arguments(PARSE_ARGV 0 IHDR
    "NO_RELATIVE_SUBDIR;SQUASH_SUBDIRS;USE_PRODUCT_NAME;USE_PROJECT_NAME"
    "SUBDIRNAME" "")
  cet_package_path(CURRENT_SUBDIR)
  if (ART_MAKE_PREPEND_PRODUCT_NAME OR # Historical compatibility.
      IHDR_USE_PROJECT_NAME OR IHDR_USE_PRODUCT_NAME)
    string(JOIN "/" IHDR_SUBDIRNAME "${IHDR_SUBDIRNAME}" "${CETMODULES_CURRENT_PROJECT_NAME}")
  endif()
  if (NOT IHDR_NO_RELATIVE_SUBDIR)
    string(JOIN "/" IHDR_SUBDIRNAME "${IHDR_SUBDIRNAME}" "${CURRENT_SUBDIR}")
  endif()
  cet_passthrough(FLAG IN_PLACE KEYWORD _SQUASH_SUBDIRS IHDR_SQUASH_SUBDIRS)
  if ("LIST" IN_LIST IHDR_UNPARSED_ARGUMENTS)
    _cet_install(headers ${CETMODULES_CURRENT_PROJECT_NAME}_INCLUDE_DIR ${IHDR_UNPARSED_ARGUMENTS}
      SUBDIRNAME ${IHDR_SUBDIRNAME} _INSTALL_ONLY ${IHDR_SQUASH_SUBDIRS})
  else()
    _cet_install(headers ${CETMODULES_CURRENT_PROJECT_NAME}_INCLUDE_DIR ${IHDR_UNPARSED_ARGUMENTS}
      SUBDIRNAME ${IHDR_SUBDIRNAME} _INSTALL_ONLY ${IHDR_SQUASH_SUBDIRS}
      _SEARCH_BUILD _EXTRA_BASENAME_EXCLUDES classes.h Linkdef.h
      _GLOBS "?*.h" "?*.hh" "?*.H" "?*.hpp" "?*.hxx" "?*.icc" "?*.tcc")
  endif()
endfunction()
