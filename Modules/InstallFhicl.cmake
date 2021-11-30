#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# install_fhicl()
#
#   Install fhicl scripts in ${${CETMODULES_CURRENT_PROJECT_NAME}_FHICL_DIR}
#
# Usage: install_fhicl([SUBDIRNAME <subdir>] LIST ...)
#        install_fhicl([SUBDIRNAME <subdir>] [BASENAME_EXCLUDES ...]
#          [EXCLUDES ...] [EXTRAS ...] [SUBDIRS ...])
#
# See CetInstall.cmake for full usage description.
#
# Recognized filename extensions: .fcl
########################################################################

# Avoid unwanted repeat inclusion.
include_guard()

include (CetInstall)
include (ProjectVariable)

function(install_fhicl)
  if (NOT "FHICL_DIR" IN_LIST CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    project_variable(FHICL_DIR "fcl" CONFIG
      OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install FHiCL files")
    if (product AND ${product}_fcldir MATCHES "^\$") # Placeholder
      cmake_language(EVAL CODE
        "set_property(CACHE ${CETMODULES_CURRENT_PROJECT_NAME}_fcldir PROPERTY VALUE \
\"${${CETMODULES_CURRENT_PROJECT_NAME}_fcldir}\"\
")
    endif()
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  if ("LIST" IN_LIST ARGN)
    _cet_install(fhicl ${CETMODULES_CURRENT_PROJECT_NAME}_FHICL_DIR ${ARGN})
  else()
    _cet_install(fhicl ${CETMODULES_CURRENT_PROJECT_NAME}_FHICL_DIR ${ARGN}
      _SQUASH_SUBDIRS _GLOBS "?*.fcl")
  endif()
endfunction()
