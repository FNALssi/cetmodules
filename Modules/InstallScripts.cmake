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
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetExclude)
include(ProjectVariable)

function(install_scripts)
  cmake_parse_arguments(PARSE_ARGV 0 IS "AS_TEST" "" "")
  set(GLOBS "?*.sh" "?*.py" "?*.pl" "?*.rb")
  list(REMOVE_ITEM IS_UNPARSED_ARGUMENTS PROGRAMS) # Avoid duplication.
  if (IS_AS_TEST)
    set(pvar TEST)
    list(APPEND GLOBS "?*.cfg")
  else()
    set(pvar SCRIPTS)
  endif()
  if ("LIST" IN_LIST IS_UNPARSED_ARGUMENTS)
    _cet_install(scripts ${CETMODULES_CURRENT_PROJECT_NAME}_${pvar}_DIR ${IS_UNPARSED_ARGUMENTS}
      PROGRAMS _INSTALL_ONLY)
  else()
    _cet_install(scripts ${CETMODULES_CURRENT_PROJECT_NAME}_${pvar}_DIR ${IS_UNPARSED_ARGUMENTS}
      PROGRAMS _INSTALL_ONLY _SQUASH_SUBDIRS _GLOBS ${GLOBS})
  endif()
endfunction()

cmake_policy(POP)
