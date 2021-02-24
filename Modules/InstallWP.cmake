########################################################################
# install_wp()
#
#   Install WP data in ${${PROJECT_NAME}_WP_DIR}/<subdir>
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

function(install_wp)
  if (NOT "WP_DIR" IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    project_variable(WP_DIR CONFIG
      OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install WP files")
    if (product AND ${product}_perllib MATCHES "^\$") # Placeholder
      cmake_language(EVAL CODE
        "set_property(CACHE ${PROJECT_NAME}_wp PROPERTY VALUE \
\"${${PROJECT_NAME}_wp}\"\
")
    endif()
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  _cet_install(wp ${PROJECT_NAME}_WP_DIR ${ARGN}
    _LIST_ONLY)
endfunction()

cmake_policy(POP)
