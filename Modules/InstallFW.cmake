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
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetInstall)
include(ProjectVariable)

function(install_fw)
  if (NOT "FW_DIR" IN_LIST CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    project_variable(FW_DIR CONFIG
      OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install FW files")
    if (product AND ${product}_fwdir MATCHES "^\$") # Placeholder
      cmake_language(EVAL CODE
        "set_property(CACHE ${CETMODULES_CURRENT_PROJECT_NAME}_fwdir PROPERTY VALUE \
\"${${CETMODULES_CURRENT_PROJECT_NAME}_fwdir}\"\
")
    endif()
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  _cet_install(fw ${CETMODULES_CURRENT_PROJECT_NAME}_FW_DIR ${ARGN} _LIST_ONLY)
endfunction()

cmake_policy(POP)
