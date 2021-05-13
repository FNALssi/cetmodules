#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# parse_version_string(<version> [SEP <sep>] <var> [<var>]...)
#
#   Parse a version string of the form:
#
#      [v]<major>(<sep><minor>(<sep><patch>)?)?(<tweak-sep>?<tweak>)?
#
#   where <sep> and <tweak-sep> are any of the usual version component
#   separators: "-" "_" or "."
#
# Notes
##################
#
#   1. Per CMake convention: <major>, <minor>, and <patch> must be
#      non-negative integers (with optional leading zeros), so <tweak>
#      starts from the first non-separator, non-numeric character.
#
#   2. If <sep> is specified, set <var> to
#      "<major><sep><minor><sep><patch><tweak-sep><tweak>"
#
#      (a) If <sep> is "." then <tweak-sep> is set to "-" per CMake
#          convention; otherwise, <tweak-sep> is empty.
#
#      (b) If multiple <var> are specified, all but the first are
#          ignored and a warning is generated.
#
#      (C) If an intermediate component is empty, it will be shown as
#          "0" in the string version.
#
#   3. If a single <var> is specified, it will be set to a list
#      consisting of <major>, <minor>, <patch>, and <tweak>.
#
#   4. Otherwise, the values of <major>, <minor>, <patch>, and <tweak>
#      will be mapped to <var>..., with extra values being discarded.
#
####################################
# to_dot_version(VERSION VAR)
#
#   to_dot_version() is provided as a convenience, wrapping a single
#   call to parse_version_string().
#
####################################
# See also to_ups_version() in Compatibility.cmake.
#
#######################################################################

include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function (parse_version_string VERSION)
  cmake_parse_arguments(PARSE_ARGV 1 PVS "" "SEP" "")
  list(POP_FRONT PVS_UNPARSED_ARGUMENTS VAR)
  if (NOT VAR)
    message(FATAL_ERROR "missing required non-option argument VAR")
  endif()
  if (DEFINED PVS_SEP AND NOT SEP IN_LIST PVS_KEYWORDS_MISSING_VALUES)
    if (PVS_UNPARSED_ARGUMENTS)
      message(WARNING "parse_version_string(): ignoring unexpected extra"
        " non-option arguments ${PVS_UNPARSED_ARGUMENTS} when SEP specified")
    endif()
    set(want_string TRUE)
  else()
    set(want_string)
  endif()
  unset(major)
  unset(minor)
  unset(patch)
  unset(tweak)
  if (VERSION MATCHES "^([-_.]+|v)?([0-9]*)([-_.]?)(.*)$")
    set(major "${CMAKE_MATCH_2}")
    set(sep "${CMAKE_MATCH_3}")
    if ("${CMAKE_MATCH_4}" MATCHES "^([0-9]*)${sep}?(.*)$")
      set(minor "${CMAKE_MATCH_1}")
      if ("${CMAKE_MATCH_2}" MATCHES "^([0-9]*)([-_.]?(.*))?$")
        set(patch "${CMAKE_MATCH_1}")
        if (CMAKE_MATCH_2 STREQUAL "")
          unset(tweak)
        else()
          set(tweak "${CMAKE_MATCH_3}")
        endif()
      endif()
    endif()
  else()
    message(FATAL_ERROR "parse_version_string() cannot parse a version from \"$VERSION\"")
  endif()
  if (DEFINED tweak AND PVS_SEP STREQUAL ".")
    set(tweak_sep "-")
  else()
    set(tweak_sep)
  endif()
  foreach (tmp_element IN ITEMS patch minor major)
    if (${tmp_element} STREQUAL "")
      if (DEFINED tmp_bits AND tmp_bits MATCHES "[^;]")
        if (want_string)
          list(PREPEND tmp_bits 0)
        else()
          list(PREPEND tmp_bits -)
        endif()
      endif()
    else()
      list(PREPEND tmp_bits "${${tmp_element}}")
    endif()
  endforeach()
  list(TRANSFORM tmp_bits REPLACE "^-$" "")
  if (PVS_SEP)
    list(JOIN tmp_bits "${PVS_SEP}" tmp_string)
    set(${VAR} "${tmp_string}${tweak_sep}${tweak}" PARENT_SCOPE)
  else()
    if (DEFINED tweak)
      list(LENGTH tmp_bits sz)
      if (sz EQUAL 0)
        set(tmp_bits ";;;${tweak}")
      else()
        math(EXPR sz "4 - ${sz}")
        string(REPEAT ";" ${sz} bits_pad)
        set(tmp_bits "${tmp_bits}${bits_pad}${tweak}")
      endif()
    endif()
    if (PVS_UNPARSED_ARGUMENTS)
      foreach (v IN LISTS VAR PVS_UNPARSED_ARGUMENTS)
        list(POP_FRONT tmp_bits tmp_element)
        set(${v} ${tmp_element} PARENT_SCOPE)
      endforeach()
    else()
      set(${VAR} "${tmp_bits}" PARENT_SCOPE)
    endif()
  endif()
endfunction()

macro(to_dot_version VERSION VAR)
  parse_version_string("${VERSION}" SEP . ${VAR})
endmacro()

cmake_policy(POP)
