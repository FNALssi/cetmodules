#[================================================================[.rst:
X
-
#]================================================================]
########################################################################
# install_fw()
#
#   Install FW data in ${${CETMODULES_CURRENT_PROJECT_NAME}_FW_DIR}/<subdir>
#
# Usage: install_wp([SUBDIRNAME <subdir>] LIST ...)
#
# See CetInstall.cmake for full usage description.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(CetInstall)
include(ProjectVariable)

function(install_fw)
  project_variable(FW_DIR CONFIG NO_WARN_DUPLICATE
    OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
    DOCSTRING "Directory below prefix to install FW files")
  if (product AND "$CACHE{${product}_fwdir}" MATCHES "^\\\$") # Resolve placeholder.
    set_property(CACHE ${product}_fwdir PROPERTY VALUE
      "${$CACHE{${product}_fwdir}}")
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  _cet_install(fw ${CETMODULES_CURRENT_PROJECT_NAME}_FW_DIR ${ARGN} _LIST_ONLY)
endfunction()
