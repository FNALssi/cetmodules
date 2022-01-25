#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# install_wp()
#
#   Install WP data in ${${CETMODULES_CURRENT_PROJECT_NAME}_WP_DIR}/<subdir>
#
# Usage: install_wp([SUBDIRNAME <subdir>] LIST ...)
#
# See CetInstall.cmake for full usage description.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetInstall)
include(ProjectVariable)

function(install_wp)
  project_variable(WP_DIR CONFIG NO_WARN_DUPLICATE
    OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
    DOCSTRING "Directory below prefix to install WP files")
  if (product AND "$CACHE{${product}_wpdir}" MATCHES "^\$") # Resolve placeholder.
    set_property(CACHE ${product}_wpdir PROPERTY VALUE
      "${$CACHE{${product}_wpdir}}")
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  _cet_install(wp ${CETMODULES_CURRENT_PROJECT_NAME}_WP_DIR ${ARGN}
    _LIST_ONLY)
endfunction()
