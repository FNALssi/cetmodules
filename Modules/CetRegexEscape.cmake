#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# cet_regex_escape(<val> <var> [<num>])
# cet_regex_escape(<val>... VAR <var> [NUM <num>])
#
#   Escape the provided string to prevent interpretation of characters
#   as special (e.g. `.') by the CMake regex engine.
#
# The result of escaping characters which would be interpreted by
# CMake's regex engine is passed through cet_armor_string if <num> is
# specified and non-zero.
#
########################################################################
# cet_armor_string(<val> <var> <num>)
# cet_armor_string(<val>... VAR <var> NUM <num>)
#
#   Armor the instances of "\" in the specified values aginst being
#   passed to a macro (and therefore being interpolated).
#
# The <num> argument indicates the expected interpolation level for
# which to compensate (default 1). Every time the values are expected to
# be passed to a macro (including cmake_parse_arguments()!), increment
# <num> to ensure that "\" are correctly handled. This is *not*
# necessary for a function.
#
########################################################################

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

# Non-disruptive CMake version requirements.
cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(cet_regex_escape)
  cmake_parse_arguments(PARSE_ARGV 0 CRE "" "VAR;NUM" "")
  # Handle options.
  _handle_regex_options([=[
USAGE: cet_regex_escape(<val> <var> <num>)
       cet_regex_escape(<val>... VAR <var> [NUM <num>])]=])
  # Escape special characters to prevent them being interpreted by the
  # regex engine.
  set(RESULT)
  foreach (val IN LISTS CRE_UNPARSED_ARGUMENTS)
    string(REGEX REPLACE [=[([].|^()?+$*\\[])]=] "\\\\\\1" val "${val}")
    string(REGEX REPLACE "/+" "/" val "${val}")
    # Armor against macro interpolation if requested via NUM.
    if (CRE_NUM GREATER 0)
      cet_armor_string("${val}" VAR val NUM ${CRE_NUM})
    endif()
    list(APPEND RESULT "${val}")
  endforeach()
  set(${CRE_VAR} "${RESULT}" PARENT_SCOPE)
endfunction()

function(cet_armor_string)
  # Handle options.
  cmake_parse_arguments(PARSE_ARGV 0 CRE "" "VAR;NUM" "")
  _handle_regex_options("\
USAGE: cet_armor_string(<val> <var> [<num>])
       cet_armor_string(<val>... VAR <var> [NUM <num>])")
  if (DEFINED CRE_UNPARSED_ARGUMENTS)
    if (NOT DEFINED CRE_NUM)
      set(CRE_NUM 1) # Default.
    endif()
    # Duplicate any escape characters found to handle interpolation by
    # CMake's macro argument handling.
    if (CRE_NUM GREATER 0)
      foreach(count RANGE 1 ${CRE_NUM})
        string(REPLACE "\\" "\\\\" CRE_UNPARSED_ARGUMENTS "${CRE_UNPARSED_ARGUMENTS}")
      endforeach()
    endif()
    set(${CRE_VAR} "${CRE_UNPARSED_ARGUMENTS}" PARENT_SCOPE)
  else()
    unset(${CRE_VAR} PARENT_SCOPE)
  endif()
endfunction()

function(_handle_regex_options MSG)
  if (NOT (DEFINED CRE_VAR OR DEFINED CRE_NUM)) # No keywords.
    list(LENGTH CRE_UNPARSED_ARGUMENTS len)
    if (len GREATER 3)
      message(FATAL_ERROR "${MSG}")
    endif()
    list(POP_FRONT CRE_UNPARSED_ARGUMENTS VAL CRE_VAR)
    set(CRE_UNPARSED_ARGUMENTS "${VAL}")
  endif()
  if (CRE_VAR)
    foreach (var IN ITEMS VAR NUM KEYWORDS_MISSING_VALUES UNPARSED_ARGUMENTS)
      if (DEFINED CRE_${var})
        set(CRE_${var} "${CRE_${var}}" PARENT_SCOPE)
      else()
        unset(CRE_${var} PARENT_SCOPE)
      endif()
    endforeach()
  else()
    message(FATAL_ERROR "${MSG}")
  endif()
endfunction()

cmake_policy(POP)
