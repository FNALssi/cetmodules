########################################################################
# install_perllib()
#
#   Install perl modules in ${${PROJECT_NAME}_PERLLIB_DIR}.
#
# Usage: install_perllib([DROP_PREFIX <dropdir>] [SUBDIRNAME <subdir>]
#                        [BASENAME_EXCLUDES ...] [EXCLUDES ...]
#                        [EXTRAS ...] [SUBDIRS ...])
#
# See CetInstall.cmake for full usage description.
#
# Recognized filename extensions: .pm
#
# Other recognized filename patterns: *README*
#
# If DROP_PREFIX is specified, remove <dropdir> at the beginning of each
# package subdirectory path before installing into
# ${${PROJECT_NAME}_PERLLIB_DIR}/<subdir>. Otherwise, drop
# ${${PROJECT_NAME}_PERLLIB_DIR}.
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetInstall)
include(CetPackagePath)
include(ProjectVariable)

function(install_perllib)
  if (NOT "PERLLIB_DIR" IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
    project_variable(PERLLIB_DIR perllib CONFIG
      OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
      DOCSTRING "Directory below prefix to install perl files")
  endif()
  list(REMOVE_ITEM ARGN PROGRAMS) # Not meaningful.
  cmake_parse_arguments(PARSE_ARGV 0 IPRL "" "DROP_PREFIX;SUBDIRNAME" "")
  if (NOT DEFINED IPRL_DROP_PREFIX)
    set(IPRL_DROP_PREFIX ${${PROJECT_NAME}_PERLLIB_DIR})
  endif()
  cet_package_path(CURRENT_SUBDIR SOURCE BASE_SUBDIR ${IPRL_DROP_PREFIX})
  string(APPEND IPRL_SUBDIRNAME "/${CURRENT_SUBDIR}")
  get_filename_component(CURRENT_SUBDIR_NAME "${CURRENT_SUBDIR}" NAME)
  set(PLUGIN_VERSION_FILE)
  if (CURRENT_SUBDIR_NAME STREQUAL "CetSkelPlugins")
    _cet_perl_plugin_version(PLUGIN_VERSION_FILE)
  endif()
  _cet_install(perllib ${PROJECT_NAME}_PERLLIB_DIR ${IPRL_UNPARSED_ARGUMENTS}
    SUBDIRNAME ${IPRL_SUBDIRNAME}
    _NO_LIST _INSTALLED_FILES_VAR ${IPRL_INSTALLED_FILES_VAR}
    _EXTRA_EXTRAS ${PLUGIN_VERSION_FILE}
    _GLOBS "?*.pm" "*README*")
  _cet_perllib_config_setup(${_INSTALLED_FILES})
endfunction( install_perllib )

macro(_cet_perl_plugin_version PLUGINVERSIONINFO_VAR)
  cet_find_package(cetlib PRIVATE REQUIRED)
  set(tmp
    ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}/PluginVersionInfo.pm)
  configure_file("${cetlib_PLUGINVERSIONINFO_PM_IN}"
    "${tmp}"
    @ONLY)
  set(${PLUGINVERSIONINFO_VAR} "${tmp}" PARENT_SCOPE)
endmacro( _cet_perl_plugin_version )

function(_cet_perllib_config_setup)
  cmake_parse_arguments(PARSE_ARGV 0 _CPCS "PLUGINS" "" "")
  if (_CPCS_PLUGINS)
    set(docstring "Location of cetmod plugin module")
  else()
    set(docstring "Location of cetmod plugin support file")
  endif()
  foreach (pmfile IN LISTS _CPCS_UNPARSED_ARGUMENTS)
    if (_CPCS_PLUGINS)
      get_filename_component(pmvarname "${pmfile}" NAME)
    else()
      set(pmvarname "${pmfile}")
    endif()
    string(REGEX REPLACE [=[[-./ ]]=] "_" pmvarname "${pmvarname}")
    string(TOUPPER "${pmvarname}" pmvarname)
    if (NOT "${pmvarname}" IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
      project_variable("${pmvarname}" TYPE FILEPATH_FRAGMENT CONFIG
        DOCSTRING "${docstring}" "${pmfile}")
    endif()
  endforeach()
endfunction( _cet_perllib_config_setup )

cmake_policy(POP)
