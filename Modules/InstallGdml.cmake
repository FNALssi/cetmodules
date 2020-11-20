########################################################################
# install_gdml()
#
#   Install gdml scripts in ${${PROJECT_NAME}_GDML_DIR}
#
# Usage: install_gdml([SUBDIRNAME <subdir>] LIST ...)
#        install_gdml([SUBDIRNAME <subdir>] [BASENAME_EXCLUDES ...]
#          [EXCLUDES ...] [EXTRAS ...] [SUBDIRS ...])
#
# See CetInstall.cmake for full usage description.
#
# Recognized filename extensions: .gdml
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include (CetInstall)
include (ProjectVariable)

function(install_gdml)
  if (NOT "GDML_DIR" IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    project_variable(GDML_DIR CONFIG
      OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install GDML geometry description files")
    if (product AND ${product}_gdmldir MATCHES "^\$") # Placeholder
      cmake_language(EVAL CODE
        "set_property(CACHE ${PROJECT_NAME}_gdmldir PROPERTY VALUE \
\"${${PROJECT_NAME}_gdmldir}\"\
")
    endif()
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  if ("LIST" IN ARGN)
    _cet_install(gdml ${PROJECT_NAME}_GDML_DIR "${ARGN}")
  else()
    _cet_install(gdml ${PROJECT_NAME}_GDML_DIR "${ARGN}"
      _SQUASH_SUBDIRS _GLOBS "?*.gdml")
  endif()
endfunction()

cmake_policy(POP)
