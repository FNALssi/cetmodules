# Add a find_dependency() call to the appropriate tracking variable.
function(_cet_add_transitive_dependency SOURCE_CALL FIRST_ARG)
  string(TOLOWER "${SOURCE_CALL}" TRANSITIVE_CALL)
  if (TRANSITIVE_CALL MATCHES "^cet_(.*)$")
    set(TRANSITIVE_CALL "${CMAKE_MATCH_1}")
  endif()
  if (TRANSITIVE_CALL STREQUAL "find_package")
    set(TRANSITIVE_CALL "find_dependency")
  endif()
  # Deal with optional leading COMPONENT <component> ourselves, as with
  # cmake_parse_arguments() we'd have to worry about what we might have
  # passed to find_package().
  if (FIRST_ARG STREQUAL "COMPONENT")
    list(POP_FRONT ARGN COMPONENT DEP)
    set(cache_var
      CETMODULES_FIND_DEPS_COMPONENT_${COMPONENT}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    set(docstring_extra " component ${COMPONENT}")
  else()
    set(DEP "${FIRST_ARG}")
    set(cache_var CETMODULES_FIND_DEPS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    unset(docstring_extra)
  endif()
  # Set up the beginning of the call.
  list(APPEND DEP ${ARGN})
  list(JOIN DEP " " tmp)
  list(APPEND ${cache_var} "${TRANSITIVE_CALL}(${tmp})")
  if (NOT DEFINED CACHE{${cache_var}})
    set(${cache_var} "${${cache_var}}" CACHE INTERNAL
      "Transitive dependency directives for ${CETMODULES_CURRENT_PROJECT_NAME}\
${docstring_extra}\
")
  else()
    set_property(CACHE ${cache_var}
      PROPERTY VALUE "${${cache_var}}")
  endif()
endfunction()
