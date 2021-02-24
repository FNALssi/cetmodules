# macros for building plugin libraries
#
# The plugin type is expected to be service, source, or module, but we
# do not enforce this in order to allow for user- or experiment-defined
# plugins.
#
# USAGE:
#
# simple_plugin( <name> <plugin type> [<basic_plugin options>]
#                [[NOP] <library list>] )
#
# Options:
#
# NOP
#
#    Dummy option for the purpose of separating (say) multi-option
#    arguments from non-option arguments.
#
# For other available options, please see
# cetbuildtools/Modules/BasicPlugin.cmake
# (https://cdcvs.fnal.gov/redmine/projects/cetbuildtools/repository/revisions/master/entry/Modules/BasicPlugin.cmake).
########################################################################
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(BasicPlugin)

set(_sp_pkg_list cetlib_except hep_concurrency cetlib fhiclcpp
  messagefacility canvas art canvas_root_io art_root_io)
set(_sp_target_list cetlib_except::cetlib_except hep_concurrency::hep_concurrency
  cetlib::cetlib fhiclcpp::fhiclcpp messagefacility::MF_MessageLogger
  canvas::canvas art::Framework_Core canvas_root_io::canvas_root_io
  art_root_io::art_root_io)
set(_sp_var_list CETLIB_EXCEPT HEP_CONCURRENCY CETLIB FHICLCPP
  MF_MESSAGELOGGER CANVAS ART_FRAMEWORK_CORE CANVAS_ROOT_IO ART_ROOT_IO)

cet_find_package(messagefacility PRIVATE QUIET)
if (messagefacility_FOUND AND TARGET messagefacility::MF_MessageLogger)
  include(mfPlugin)
  include(mfStatsPlugin)
endif()

include(modulePlugin)
include(pluginPlugin)
include(servicePlugin)
include(sourcePlugin)
include(toolPlugin)

# Simple plugin libraries - art suite packages are found automatically.
function(simple_plugin)
  foreach (pkg tgt var IN ZIP_LISTS
      _sp_pkg_list _sp_target_list _sp_var_list)
    message(STATUS "pkg=${pkg}")
    message(STATUS "tgt=${tgt}")
    message(STATUS "var=${var}")
    if (NOT (TARGET ${tgt} OR var))
      cet_find_package(${pkg} PRIVATE QUIET REQUIRED)
    endif()
  endforeach()
  build_plugin(${ARGV})
endfunction()

# Per simple_plugin() without the overhead of finding packages one may
# not need.
function(build_plugin NAME TYPE)
  if (COMMAND ${TYPE}_plugin)
    cmake_language(CALL ${TYPE}_plugin ${NAME} ${ARGN})
    return()
  endif()
  message(AUTHOR_WARNING "no ${TYPE}_plugin() found: calling basic_plugin()")
  basic_plugin(${NAME} ${TYPE} ${ARGN})
endfunction()

cmake_policy(POP)
