########################################################################
# find_ups_boost([BOOST_TARGETS] [<min-ver>])
#
# BOOST_TARGETS
#   If this option is specified, the modern idiom of specifying Boost
#   libraries by target e.g. Boost::unit_test_framework should be
#   followed. Otherwise, a backward compatibilty option will be
#   activated to create Boost_XXXX_LIBRARY variables for use when
#   linking.
#
#  <min-ver> - optional minimum version
#
# We look for nearly all of the boost libraries except math,
# prg_exec_monitor, test_exec_monitor
#
# If you need any that aren't specified in boost_liblist below, you
# should add your own COMPONENTS... option (after VERSION or any --
# separator).
#
# N.B. This macro is DEPRECATED: please use cet_find_package(Boost ...)
# and target notation instead.
########################################################################
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetFindPackage)
include(Compatibility)
include(ParseVersionString)

set(_FUP_liblist
  chrono date_time filesystem graph iostreams locale prg_exec_monitor
  program_options random regex serialization system thread timer
  unit_test_framework wave wserialization)

macro(find_ups_boost)
  warn_deprecated("find_ups_boost()" NEW
    "cet_find_package(Boost ...) and standard target notation")
  
  _parse_fup_arguments(boost ${ARGN} PROJECT Boost _OPTS "BOOST_TARGETS")

  if (NOT _FUP_BOOST_TARGETS)
    set(_fub_no_boost_cmake ${_FUP_PROJECT}_NO_BOOST_CMAKE)
    set(${_FUP_PROJECT}_NO_BOOST_CMAKE ON)
  endif()

  if (_FUP_DOT_VERSION)
    # Remove FNAL-specific version trailer.
    string(REGEX REPLACE [=[[a-z]+[0-9]*$]=] ""
      _FUP_DOT_VERSION "${_FUP_DOT_VERSION}")
  endif()

  set(BOOST_ROOT $ENV{BOOST_DIR})
  set(BOOST_INCLUDEDIR $ENV{BOOST_INC})
  set(BOOST_LIBRARYDIR $ENV{BOOST_LIB})
  set(${_FUP_PROJECT}_USE_MULTITHREADED ON)
  set(${_FUP_PROJECT}_NO_SYSTEM_PATHS ON)
  # Non-option arguments were always ignored in the historical
  # implementation of find_ups_boost(), so we do this here also.
  cet_find_package(${_FUP_PROJECT} ${_FUP_DOT_VERSION}
    COMPONENTS ${_FUP_liblist})
  if (${_FUP_PROJECT}_FOUND AND NOT
      (_FUP_INTERFACE OR _FUP_INCLUDED_${_FUP_PROJECT}))
    include_directories(SYSTEM $ENV{BOOST_INC})
    set(_FUP_INCLUDED_${_FUP_PROJECT} TRUE)
  endif()
  if (DEFINED _fub_no_boost_cmake)
    set(${_FUP_PROJECT}_NO_BOOST_CMAKE ${_fub_no_boost_cmake})
    unset(${_fub_no_boost_cmake})
  endif()
endmacro()

cmake_policy(POP)
