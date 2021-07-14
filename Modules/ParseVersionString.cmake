#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# parse_version_string(<version>
#                      [SEP <output-sep>
#                       [NO_EXTRA|EXTRA_SEP <output-extra-sep>]]
#                      <var> [<var>]...)
#
#   Parse a version string of the form:
#
#      [v][<major>[<sep><minor>[<sep><patch>[<sep><tweak>]]]][<extra-sep>][<extra>]
#
#   where <sep> and <extra-sep> are any of the usual version component
#   separators: "-" "_" or "." and <major>, <minor>, <patch>, and
#   <tweak> are non-negative integers, per CMake requirements.
#
# Notes
##################
#
#   1. Per CMake convention: <major>, <minor>, <patch>, and <tweak> must
#      be non-negative integers (with optional leading zeros), so
#      <extra> starts from the first non-separator, non-numeric
#      character.
#
#   2. If <sep> is specified, set <var> to
#      "<major><sep><minor><sep><patch><extra-sep><extra>"
#
#      (a) <extra-sep> is empty unless specified.
#
#      (b) If multiple <var> are specified, all but the first are
#          ignored and a warning is generated.
#
#      (c) If an intermediate component is empty, it will be shown as
#          "0" in the string version.
#
#   3. If a single <var> is specified, it will be set to a list
#      consisting of <major>, <minor>, <patch>, <tweak>, and <extra>.
#      Otherwise, the values of <major>, <minor>, <patch>, <tweak>, and
#      <extra> will be mapped to <var>..., with extra values being
#      discarded.
#
####################################
# to_cmake_version(<version> <var>)
#
#   to_cmake_version() is provided as a convenience, equivalent to:
#
#     parse_version_string(<version> SEP . NO_EXTRA)
#
####################################
# to_dot_version(<version> <var>)
#
#   to_dot_version() is provided as a convenience, equivalent to:
#
#     parse_version_string(<version> SEP . <var>)
#
####################################
# to_version_string(<version> <var>)
#
#   to_version_string() is provided as a convenience, equivalent to:
#
#     parse_version_string(<version> SEP . EXTRA_SEP - <var>)
#
####################################
#
# See also to_ups_version() in compat/Compatibility.cmake and
# check_prod_version() in compat/CheckProdVersion.cmake.
#
#######################################################################

include_guard(DIRECTORY)

cmake_policy(PUSH)
# Need list(POP_FRONT...).
cmake_minimum_required(VERSION 3.15 FATAL_ERROR)

set(CET_PARSE_VERSION_STRING_MIN_CETMODULES_VERSION 2.21.00)

function (parse_version_string _PVS_VERSION)
  # Argument parsing and validation.
  cmake_parse_arguments(PARSE_ARGV 1 PVS "NO_EXTRA" "EXTRA_VAR;PREAMBLE;SEP;EXTRA_SEP" "")
  list(POP_FRONT PVS_UNPARSED_ARGUMENTS _PVS_VAR)
  if (NOT _PVS_VAR)
    message(FATAL_ERROR "missing required non-option argument VAR")
  endif()
  if (DEFINED PVS_SEP AND PVS_UNPARSED_ARGUMENTS)
    message(WARNING "parse_version_string(): ignoring unexpected extra"
      " non-option arguments ${PVS_UNPARSED_ARGUMENTS} when SEP specified")
  endif()
  if (PVS_SEP STREQUAL "")
    if (DEFINED PVS_EXTRA_SEP)
      message(WARNING "EXTRA_SEP ignored without non-vacuous SEP")
      unset(PVS_EXTRA_SEP)
    endif()
    if (PVS_NO_EXTRA)
      message(WARNING "NO_EXTRA ignored without non-vacuous SEP")
      unset(PVS_NO_EXTRA)
    endif()
    if (PVS_EXTRA_VAR)
      message(WARNING "EXTRA_VAR ignored without non-vacuous SEP")
      unset(PVS_EXTRA_VAR)
    endif()
  elseif (PVS_NO_EXTRA AND PVS_EXTRA_SEP)
    message(FATAL_ERROR "NO_EXTRA and EXTRA_SEP are mutually-exclusive")
  endif()
  # Initialize intermediate variables.
  unset(_pvs_extra)
  unset(_pvs_extra_bits)
  unset(_pvs_tmp_bits)
  set(_pvs_sep_def "[-_.]")
  if (${_PVS_VERSION} MATCHES "^.+$") # Handle a level of indirection.
    set(_PVS_VERSION "${CMAKE_MATCH_0}")
  else()
    set(_PVS_VERSION "")
  endif()
  list(LENGTH _PVS_VERSION _pvs_sz)
  if (_pvs_sz GREATER 1) # We have a pre-parsed list.
    if (_pvs_sz GREATER 4) # We have a trailing non-numeric version component.
      list(GET _PVS_VERSION 4 _pvs_extra)
      list(SUBLIST _PVS_VERSION 5 -1 _pvs_extra_bits)
    endif()
    list(SUBLIST _PVS_VERSION 0 4 _pvs_tmp_bits)
  elseif (NOT "${_PVS_VERSION}" STREQUAL "")
    set(_pvs_failed TRUE)
    unset(_pvs_major)
    unset(_pvs_minor)
    unset(_pvs_patch)
    unset(_pvs_tweak)
    if ("${_PVS_VERSION}" MATCHES "^v?([0-9]*)(${_pvs_sep_def}?)(.*)$")
      set(_pvs_major "${CMAKE_MATCH_1}")
      if (NOT "${CMAKE_MATCH_2}" STREQUAL "")
        set(_pvs_sep "[${CMAKE_MATCH_2}]")
      else()
        set(_pvs_sep "${_pvs_sep_def}")
      endif()
      if ("${CMAKE_MATCH_3}" MATCHES "^([0-9]*)${_pvs_sep}?(.*)$")
        set(_pvs_minor "${CMAKE_MATCH_1}")
        if ("${CMAKE_MATCH_2}" MATCHES "^([0-9]*)${_pvs_sep}?(.*)$")
          set(_pvs_patch "${CMAKE_MATCH_1}")
          # Allow a different separator for the non-numeric component.
          if ("${CMAKE_MATCH_2}" MATCHES "^([0-9]*)(${_pvs_sep_def}?(.*))$")
            set(_pvs_tweak "${CMAKE_MATCH_1}")
            if (NOT "${CMAKE_MATCH_2}" STREQUAL "")
              set(_pvs_extra "${CMAKE_MATCH_3}")
            endif()
            set(_pvs_failed FALSE)
          endif()
        endif()
      endif()
    endif()
    if (_pvs_failed)
      message(FATAL_ERROR "parse_version_string() cannot parse a version from \"${_PVS_VERSION}\"")
    else()
      # Make sure a non-empty component is placed at the correct place
      # in the _pvs_tmp_bits component list. Fill with "0<sep>" if we're
      # generating a string.
      foreach (_pvs_tmp_element IN ITEMS _pvs_tweak _pvs_patch _pvs_minor _pvs_major)
        # Important to go through the components in reverse.
        if (${_pvs_tmp_element} STREQUAL "")
          if ("${_pvs_tmp_bits}" MATCHES "[^;]")
            if ("${PVS_SEP}" STREQUAL "")
              # Need at least a placeholder while we're building the
              # array.
              string(PREPEND _pvs_tmp_bits ";")
            else()
              list(PREPEND _pvs_tmp_bits 0)
            endif()
          endif()
        else()
          list(INSERT _pvs_tmp_bits 0 "${${_pvs_tmp_element}}")
        endif()
      endforeach()
    endif()
  endif()
  if (PVS_SEP)
    # Generating a string.
    list(JOIN _pvs_tmp_bits "${PVS_SEP}" _pvs_tmp_string)
    if (NOT _pvs_extra STREQUAL "" AND NOT PVS_NO_EXTRA)
      string(APPEND _pvs_tmp_string "${PVS_EXTRA_SEP}${_pvs_extra}")
    endif()
    if (NOT "${PVS_EXTRA_VAR}" STREQUAL "")
      set(${PVS_EXTRA_VAR} "${_pvs_extra}" PARENT_SCOPE)
    endif()
    set(${_PVS_VAR} "${PVS_PREAMBLE}${_pvs_tmp_string}" PARENT_SCOPE)
  else()
    if (DEFINED _pvs_extra)
      # Make sure the bits array is padded appropriately.
      list(LENGTH _pvs_tmp_bits _pvs_sz)
      if (_pvs_sz EQUAL 0)
        set(_pvs_tmp_bits ";;;;${_pvs_extra}")
      else()
        math(EXPR _pvs_pad_sz "5 - ${_pvs_sz}")
        string(REPEAT ";" ${_pvs_pad_sz} _pvs_bits_pad)
        string(APPEND _pvs_tmp_bits "${_pvs_bits_pad}${_pvs_extra}")
        unset(_pvs_pad_sz)
      endif()
      if (NOT (_pvs_extra STREQUAL "" OR DEFINED _pvs_extra_bits))
        _cet_parse_version_extra()
      endif()
      list(APPEND _pvs_tmp_bits ${_pvs_extra_bits})
    endif()
    if (PVS_UNPARSED_ARGUMENTS)
      # Put each component in a variable.
      foreach (_pvs_v IN LISTS _PVS_VAR PVS_UNPARSED_ARGUMENTS)
        list(POP_FRONT _pvs_tmp_bits _pvs_tmp_element)
        set(${_pvs_v} ${_pvs_tmp_element} PARENT_SCOPE)
      endforeach()
    else()
      # Return the result as a list of components.
      set(${_PVS_VAR} "${_pvs_tmp_bits}" PARENT_SCOPE)
    endif()
  endif()
endfunction()

macro(to_cmake_version _TCV_VERSION _TCV_VAR)
  parse_version_string(${_TCV_VERSION} SEP . NO_EXTRA ${_TCV_VAR})
endmacro()

macro(to_dot_version _TDV_VERSION _TDV_VAR)
  parse_version_string(${_TDV_VERSION} SEP . ${_TDV_VAR})
endmacro()

macro(to_version_string _TDV_VERSION _TDV_VAR)
  parse_version_string(${_TDV_VERSION} SEP . EXTRA_SEP - ${_TDV_VAR})
endmacro()

function(_cet_parse_version_extra)
  if ("${_pvs_extra}" MATCHES "[0-9]+(\\.?[0-9]*)?$")
    set(_pe_num "${CMAKE_MATCH_0}")
    string(FIND "${_pvs_extra}" "${_pe_num}" _pe_num_idx REVERSE)
    string(SUBSTRING "${_pvs_extra}" 0 ${_pe_num_idx} _pe_text)
    if (_pe_text MATCHES "^(.*)[_.-]$") # Trim text-num separator.
      set(_pe_text "${CMAKE_MATCH_1}")
    endif()
  else()
    set(_pe_num)
    set(_pe_text "${_pvs_extra}")
  endif()
  string(TOLOWER "${_pe_text}" _pe_text_l)
  if (_pe_text STREQUAL "")
    set(_pe_type 0)
  elseif (_pe_text_l MATCHES "^(.+-)?(nightly|snapshot)$")
    if (_pvs_sz)
      set(_pe_type 3)
    else() # No numeric version component.
      set(_pe_type 103)
    endif()
  elseif (_pvs_sz EQUAL 0) # No leading numeric component at all.
    set(_pe_type 101)
    set(_pe_num)
    set(_pe_text "${_pvs_extra}")
  elseif (_pe_text_l STREQUAL "patch" OR (_pe_text_l STREQUAL "p" AND NOT _pe_num STREQUAL ""))
    set(_pe_type 1)
  elseif (_pe_text_l STREQUAL "rc" OR _pe_text_l STREQUAL "pre")
    set(_pe_type -1)
  elseif (_pe_text_l STREQUAL "gamma")
    set(_pe_type -2)
  elseif (_pe_text_l STREQUAL "beta")
    set(_pe_type -3)
  elseif (_pet_ext_l STREQUAL "alpha")
    set(_pe_type -4)
  else()
    set(_pe_type 2)
    set(_pe_text "${_pe_text_l}") # Standardize for comparison.
  endif()
  set(_pvs_extra_bits ${_pe_type} "${_pe_text}" ${_pe_num} PARENT_SCOPE)
endfunction()

cmake_policy(POP)
