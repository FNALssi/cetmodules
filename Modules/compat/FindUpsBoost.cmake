#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# find_ups_boost([BOOST_TARGETS] [<min-ver>])
#
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
# N.B. This macro is DEPRECATED: please use find_package(Boost ...)
# and target notation instead.
########################################################################
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(Compatibility)
include(ParseVersionString)

set(_FUB_liblist
  chrono date_time filesystem graph iostreams locale prg_exec_monitor
  program_options random regex serialization system thread timer
  unit_test_framework wave wserialization)

macro(find_ups_boost)
  warn_deprecated("find_ups_boost()" NEW
    "find_package(Boost ...) and standard target notation")
  _parse_fup_arguments(boost ${ARGN} PROJECT Boost)
  if (NOT _FUB_INCLUDED)
    set(BOOST_ROOT $ENV{BOOST_DIR})
    set(BOOST_INCLUDEDIR $ENV{BOOST_INC})
    set(BOOST_LIBRARYDIR $ENV{BOOST_LIB})
    set(${_FUP_PROJECT}_USE_MULTITHREADED ON)
    set(${_FUP_PROJECT}_NO_SYSTEM_PATHS ON)
    # Non-option arguments were always ignored in the historical
    # implementation of find_ups_boost(), so we do this here also.
    find_package(${_FUP_PROJECT} ${_FUP_DOT_VERSION}
      COMPONENTS ${_FUB_liblist} REQUIRED)
    if (${_FUP_PROJECT}_FOUND)
      include_directories(SYSTEM $ENV{BOOST_INC})
      set(_FUB_INCLUDED TRUE)
    endif()
  endif()
endmacro()

cmake_policy(POP)
