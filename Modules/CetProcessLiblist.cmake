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
  set(scope PRIVATE)
  foreach (arg IN LISTS ARGN)
    if (arg MATCHES "^(INTERFACE|PRIVATE|PUBLIC)$")
      set(scope "${arg}")
    elseif (NOT (TARGET "${arg}" OR arg MATCHES
          "(/|::|^((-|\\$<)|(debug|general|optimized)$))"))
      _cet_convert_target_arg("${arg}" arg)
    endif()
    list(APPEND RESULTS "${arg}")
  endforeach()
  set(${RESULT_VAR} "${RESULTS}" PARENT_SCOPE)
endfunction()

function(_cet_convert_target_arg ARG RESULT_VAR)
  set(DOLLAR "@CET_DOLLAR@")
  # Can we convert it to an uppercase variable we can substitute?
  string(TOUPPER "${ARG}" ${ARG}_UC)
  if (${${ARG}_UC})
    # Delay expansion for variables resolving to paths
    if (${${ARG}_UC} MATCHES "/")
	    set(RESULT "PRIVATE" "${${${ARG}_UC}}" "INTERFACE"
        "$<BUILD_INTERFACE:${${${ARG}_UC}}>"
        "$<INSTALL_INTERFACE:${DOLLAR}{${${ARG}_UC}}>" ${scope})
    else()
      set(RESULT "${${${ARG}_UC}}")
    endif()
  else()
	  set(RESULT "${ARG}")
  endif()
  set(${RESULT_VAR} "${RESULT}" PARENT_SCOPE)
endfunction()

cmake_policy(POP)
