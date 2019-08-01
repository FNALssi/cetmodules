########################################################################
# install_fw()
#
#   Install FW data in ${${PROJECT_NAME}_FW_DIR}/<subdir>
#
# Usage: install_wp([SUBDIRNAME <subdir>] LIST ...)
#
# See CetInstall.cmake for full usage description.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

include(CetInstall)
include(ProjectVariable)

function(install_fw)
  if (NOT "FW_DIR" IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    project_variable(FW_DIR CONFIG
      OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install FW files")
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  _cet_install(fw ${PROJECT_NAME}_FW_DIR ${ARGN} _LIST_ONLY)
endfunction()
