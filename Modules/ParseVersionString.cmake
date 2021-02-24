########################################################################
# parse_version_string(VERSION [SEP <separator>] VAR [VAR]...)
#
#   Parse a generic version string into the specified form:
#
#   1. If SEP is specified, set VAR to
#      "MAJOR${SEP}MINOR${SEP}PATCH[${SEP}]TWEAK"
#
#      (a) If PATCH is all numbers and TWEAK starts with a letter, then
#          PATCH and TWEAK are not separated.
#
#      (b) If multiple VARs are specified, all but the first are ignored
#          and a warning is generated.
#
#   2. If a single VAR is specified, it will be set to a list consisting
#      of MAJOR, MINOR, PATCH, and TWEAK.
#
#   3. Otherwise, the values of MAJOR, MINOR, PATCH, and TWEAK will be
#      mapped to VAR..., with extra values being discarded.
#
####################################
# to_dot_version(VERSION VAR)
#
#   to_dot_version() is provided as a convenience, wrapping a single call to parse_version_string().
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
  if (PVS_SEP AND PVS_UNPARSED_ARGUMENTS)
    message(WARNING "parse_version_string(): ignoring unexpected extra"
      " non-option arguments ${PVS_UNPARSED_ARGUMENTS} when SEP specified")
  endif()
  if (VERSION MATCHES "^v?([^-_.]+)[-_.]?(.*)$")
    set(major "${CMAKE_MATCH_1}")
    if ("${CMAKE_MATCH_2}" MATCHES "^([^-_.]+)[-_.]?(.*)$")
      set(minor "${CMAKE_MATCH_1}")
      if ("${CMAKE_MATCH_2}" MATCHES "^([^-_.]+)([-_.])?(.*)$")
        set(patch "${CMAKE_MATCH_1}")
        if (CMAKE_MATCH_3)
          set(tweak "${CMAKE_MATCH_3}")
        elseif (patch MATCHES "^([0-9]+)(.*)$")
          set(patch "${CMAKE_MATCH_1}")
          set(tweak "${CMAKE_MATCH_2}")
        endif()
      endif()
    endif()
  endif()
  if (PVS_SEP)
    string(JOIN "${PVS_SEP}" tmp_string "${major}" "${minor}" "${patch}")
    if (tweak MATCHES "^[A-Za-z].*$" AND patch MATCHES "^[0-9]+$")
      set(${VAR} "${tmp_string}${tweak}" PARENT_SCOPE)
    else()
      string(JOIN "${PVS_SEP}" tmp_string ${tmp_string} ${tweak})
      set(${VAR} ${tmp_string} PARENT_SCOPE)
    endif()
  elseif (PVS_UNPARSED_ARGUMENTS)
    set(tmp_bits "${major}" "${minor}" "${patch}" "${tweak}")
    foreach (v IN LISTS VAR PVS_UNPARSED_ARGUMENTS)
      list(POP_FRONT tmp_bits tmp_element)
      set(${v} ${tmp_element} PARENT_SCOPE)
    endforeach()
  else()
    set(${VAR} "${major}" "${minor}" "${patch}" "${tweak}" PARENT_SCOPE)
  endif()
endfunction()

function(to_dot_version VERSION VAR)
  parse_version_string("${VERSION}" SEP . tmp)
  set(${VAR} "${tmp}" PARENT_SCOPE)
endfunction()

cmake_policy(POP)
