########################################################################
# install_source()
#
#   Install source files under ${${PROJECT_NAME}_INSTALLED_SOURCE_DIR}
#
# Usage: install_source([SUBDIRNAME <subdir>] LIST ...)
#        install_source([SUBDIRNAME <subdir>] [BASENAME_EXCLUDES ...]
#          [EXCLUDES ...] [EXTRAS ...] [SUBDIRS ...])
#
# See CetInstall.cmake for full usage description.
#
# Recognized filename extensions:
#   .h .hh .H .hpp .hxx .icc .tcc
#   .c .cc .cpp .C .cxx
#   .sh .py .pl .rb .xml .dox
#
# Other recognized patterns:
#   INSTALL* *README* LICENSE LICENSE.* COPYING COPYING.*
#
# Excluded files:
#   ?*.bak ?*.~ ?*.~[0-9]* ?*.old ?*.orig ?*.rej #*# .DS_Store
#
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

include(CetInstall)
include(CetPackagePath)
include(ProjectVariable)

function(install_source) 
  if (NOT "INSTALLED_SOURCE_DIR" IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    project_variable(INSTALLED_SOURCE_DIR "source" CONFIG
      OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install source files for debug and other purposes")
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  cmake_parse_arguments(PARSE_ARGV 0 IS "" "SUBDIRNAME" "")
  cet_package_path(CURRENT_SUBDIR)
  string(APPEND IS_SUBDIRNAME "/${CURRENT_SUBDIR}")
  _cet_install(source ${PROJECT_NAME}_INSTALLED_SOURCE_DIR ${IS_UNPARSED_ARGUMENTS}
    SUBDIRNAME ${IS_SUBDIRNAME}
    _SEARCH_BUILD _INSTALL_ONLY
    _EXTRA_BASENAME_EXCLUDES "?*.bak" "?*.~" "?*.~[0-9]*" "?*.old"
    "?*.orig" "?*.rej" "#*#" ".DS_Store"
    _GLOBS "?*.h" "?*.hh" "?*.H" "?*.hpp" "?*.hxx" "?*.icc" "?*.tcc"
    "?*.c" "?*.cc" "?*.C" "?*.cpp" "?*.cxx"
    "?*.sh" "?*.py" "?*.pl" "?*.rb" "?*.xml" "?*.dox"
    "INSTALL*" "*README*" "LICENSE" "LICENSE.*" "COPYING" "COPYING.*")
endfunction()
