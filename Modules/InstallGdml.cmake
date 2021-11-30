#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# install_gdml()
#
#   Install gdml scripts in ${${CETMODULES_CURRENT_PROJECT_NAME}_GDML_DIR}
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
include_guard()

cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include (CetInstall)
include (ProjectVariable)

function(install_gdml)
  if (NOT "GDML_DIR" IN_LIST CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    project_variable(GDML_DIR "gdml" CONFIG
      OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install GDML geometry description files")
    if (product AND ${product}_gdmldir MATCHES "^\$") # Placeholder
      cmake_language(EVAL CODE
        "set_property(CACHE ${CETMODULES_CURRENT_PROJECT_NAME}_gdmldir PROPERTY VALUE \
\"${${CETMODULES_CURRENT_PROJECT_NAME}_gdmldir}\"\
")
    endif()
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  if ("LIST" IN_LIST ARGN)
    _cet_install(gdml ${CETMODULES_CURRENT_PROJECT_NAME}_GDML_DIR ${ARGN})
  else()
    _cet_install(gdml ${CETMODULES_CURRENT_PROJECT_NAME}_GDML_DIR ${ARGN}
      _GLOBS "?*.C" "?*.gdml" "?*.xml" "?*.xsd" "README")
  endif()
  # Historical compatibility.
  if ("cetbuildtools" IN_LIST ${CETMODULES_CURRENT_PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES)
    set(gdml_install_dir "${${CETMODULES_CURRENT_PROJECT_NAME}_GDML_DIR}" PARENT_SCOPE)
  endif()
endfunction()
