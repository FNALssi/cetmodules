#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# install_scripts()
#
# Install scripts in ${${CETMODULES_CURRENT_PROJECT_NAME}_SCRIPTS_DIR} or
# ${${CETMODULES_CURRENT_PROJECT_NAME}_TEST_DIR} (if marked AS_TEST).
#
# Usage: install_scripts([SUBDIRNAME <subdir>] [AS_TEST] LIST ...)
#        install_scripts([SUBDIRNAME <subdir>] [BASENAME_EXCLUDES ...]
#          [EXCLUDES ...] [EXTRAS ...] [SUBDIRS ...]
#          [AS_TEST])
#
# See CetInstall.cmake for full usage description.
#
# Recognized filename extensions: 
#   .sh .py .pl .rb (and .cfg when AS_TEST is specified)
#
########################################################################

# Avoid unwanted repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetExclude)
include(ProjectVariable)

function(install_scripts)
  cmake_parse_arguments(PARSE_ARGV 0 IS "AS_TEST" "DEST_VAR" "")
  set(GLOBS "?*.sh" "?*.py" "?*.pl" "?*.rb")
  list(REMOVE_ITEM IS_UNPARSED_ARGUMENTS PROGRAMS) # Avoid duplication.
  if (IS_AS_TEST)
    if (DEFINED IS_DEST_VAR OR DEST_VAR IN_LIST IS_KEYWORDS_MISSING_VALUES)
      message(FATAL_ERROR "AS_TEST is incompatible with DEST_VAR")
    endif()
    set(IS_DEST_VAR TEST_DIR)
  elseif (NOT DEFINED IS_DEST_VAR)
    set(IS_DEST_VAR BIN_DIR)
  endif()
  if ("LIST" IN_LIST IS_UNPARSED_ARGUMENTS)
    _cet_install(scripts ${CETMODULES_CURRENT_PROJECT_NAME}_${IS_DEST_VAR}
      ${IS_UNPARSED_ARGUMENTS}
      PROGRAMS _INSTALL_ONLY)
  else()
    _cet_install(scripts ${CETMODULES_CURRENT_PROJECT_NAME}_${IS_DEST_VAR}
      ${IS_UNPARSED_ARGUMENTS}
      PROGRAMS _INSTALL_ONLY _SQUASH_SUBDIRS _GLOBS ${GLOBS})
    if (IS_AS_TEST)
      # Don't force installed .cfg files to be executable.
      _cet_install(scripts ${CETMODULES_CURRENT_PROJECT_NAME}_${IS_DEST_VAR}
        ${IS_UNPARSED_ARGUMENTS}
        _INSTALL_ONLY _SQUASH_SUBDIRS _GLOBS "?*.cfg")
    endif()
  endif()
endfunction()
