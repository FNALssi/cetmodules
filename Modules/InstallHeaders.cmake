########################################################################
# install_headers()
#
#   Install headers scripts under
#     ${${PROJECT_NAME}_INCLUDE_DIR}[/${PROJECT_NAME}]
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
# directory ${PROJECT_NAME} to
# ${${PROJECT_NAME}_INCLUDE_DIR}/<subdir>. In any case, the current
# package subdirectory will be appended to the result followed by any
# SUBDIRS for files found therein.
#
# Build directories will be searched for suitable files.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

include(CetInstall)
include(CetPackagePath)

function(install_headers)
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  cmake_parse_arguments(PARSE_ARGV 0 IHDR "USE_PRODUCT_NAME;USE_PROJECT_NAME"
    "SUBDIRNAME" "")
  cet_package_path(CURRENT_SUBDIR)
  if (ART_MAKE_PREPEND_PRODUCT_NAME OR # Historical compatibility.
      IHDR_USE_PROJECT_NAME OR IHDR_USE_PRODUCT_NAME)
    string(APPEND IHDR_SUBDIRNAME "/${PROJECT_NAME}")
  endif()
  string(APPEND IHDR_SUBDIRNAME "/${CURRENT_SUBDIR}")
  _cet_install(headers ${PROJECT_NAME}_INCLUDE_DIR ${IHDR_UNPARSED_ARGUMENTS}
    SUBDIRNAME ${IHDR_SUBDIRNAME}
    _SEARCH_BUILD _INSTALL_ONLY
    _EXTRA_BASENAME_EXCLUDES classes.h Linkdef.h
    _GLOBS "?*.h" "?*.hh" "?*.H" "?*.hpp" "?*.hxx" "?*.icc" "?*.tcc")
endfunction()
