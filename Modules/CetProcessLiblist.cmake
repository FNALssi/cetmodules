#[================================================================[.rst:
X
=
#]================================================================]

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(cet_process_liblist RESULT_VAR)
  cet_convert_target_args(${ARGV})
  set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

function(cet_convert_target_args RESULT_VAR)
  set(RESULTS)
  foreach (arg IN LISTS ARGN)
    if (NOT (TARGET "${arg}" OR arg MATCHES
          "(/|::|^((-|\\$<)|(INTERFACE|PRIVATE|PUBLIC|debug|general|optimized)$))"))
      _cet_convert_target_arg("${arg}" arg)
    endif()
    # Pass through as-is.
    list(APPEND RESULTS "${arg}")
  endforeach()
  set(${RESULT_VAR} "${RESULTS}" PARENT_SCOPE)
endfunction()

function(_cet_convert_target_arg ARG RESULT_VAR)
  # Can we convert it to an uppercase variable we can substitute?
  string(TOUPPER "${ARG}" ${ARG}_UC)
  if (DEFINED ${${ARG}_UC} AND ${${ARG}_UC})
	  list(APPEND RESULT "${${${ARG}_UC}}")
  else()
	  list(APPEND RESULT "${ARG}")
  endif()
  set(${RESULT_VAR} "${RESULT}" PARENT_SCOPE)
endfunction()

cmake_policy(POP)
