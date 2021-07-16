# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(Compatibility)
include(CetRegexEscape)

function(cet_have_qual QUAL)
  warn_deprecated("cet_have_qual()" NEW "option() or CMake Cache variables")
  cmake_parse_arguments(PARSE_ARGV 1 CHQ "REGEX" "" "")
  list(POP_FRONT CHQ_UNPARSED_ARGUMENTS OUT_VAR)
  if (NOT OUT_VAR)
    set(OUT_VAR CET_HAVE_QUAL)
  endif()
  if (NOT CHQ_REGEX)
    cet_regex_escape("${QUAL}" QUAL)
  endif()
  if (${CETMODULES_CURRENT_PROJECT_NAME}_QUALIFIER_STRING MATCHES "(^|:)${QUAL}(:|$)")
    set(${OUT_VAR} TRUE PARENT_SCOPE)
  else()
    set(${OUT_VAR} FALSE PARENT_SCOPE)
  endif()
endfunction()

cmake_policy(POP)
