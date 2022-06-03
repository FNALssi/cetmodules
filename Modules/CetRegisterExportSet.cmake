#[================================================================[.rst:
X
=
#]================================================================]
include_guard()

cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(cet_register_export_set)
  cmake_parse_arguments(PARSE_ARGV 0 CRES
    "NO_REDEFINE;SET_DEFAULT" "NAMESPACE;NAMESPACE_VAR;SET_NAME;SET_VAR" "")
  project_variable(DEFAULT_EXPORT_SET TYPE BOOL NO_WARN_DUPLICATE
    DOCSTRING "\
Default export set to use for targets installed by CET commands. \
Also used for determining namespace for local aliases\
")
  if (CRES_SET_NAME)
    set(EXPORT_SET "${CRES_SET_NAME}")
  else()
    if (CRES_SET_DEFAULT)
      # Reset to original value.
      unset(${CETMODULES_CURRENT_PROJECT_NAME}_DEFAULT_EXPORT_SET)
      unset(${CETMODULES_CURRENT_PROJECT_NAME}_DEFAULT_EXPORT_SET PARENT_SCOPE)
    endif()
    set(EXPORT_SET "${${CETMODULES_CURRENT_PROJECT_NAME}_DEFAULT_EXPORT_SET}")
  endif()
  if (NOT EXPORT_SET MATCHES "^${CETMODULES_CURRENT_PROJECT_NAME}")
    string(PREPEND EXPORT_SET "${CETMODULES_CURRENT_PROJECT_NAME}")
  endif()
  if (NOT CRES_SET_NAME)
    message(VERBOSE "unspecified export set defaults to ${EXPORT_SET}")
  elseif (NOT CRES_SET_NAME STREQUAL EXPORT_SET)
    message(VERBOSE "export set name ${CRES_SET_NAME} -> ${EXPORT_SET} to avoid clashes")
  endif()
  if (NOT "${EXPORT_SET}" IN_LIST CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
    if (NOT DEFINED CACHE{CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}})
      set(CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME} "${EXPORT_SET}"
        CACHE INTERNAL "List of export sets for ${CETMODULES_CURRENT_PROJECT_NAME}")
    else()
      set_property(CACHE CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
        APPEND PROPERTY VALUE "${EXPORT_SET}")
    endif()
    if (NOT CRES_NAMESPACE)
      set(CRES_NAMESPACE ${${CETMODULES_CURRENT_PROJECT_NAME}_NAMESPACE})
    endif()
    if (NOT CRES_NAMESPACE)
      string(TOLOWER "${CETMODULES_CURRENT_PROJECT_NAME}" CRES_NAMESPACE)
      string(REPLACE "-" "_" CRES_NAMESPACE "${CRES_NAMESPACE}")
    endif()
    if (CRES_NAMESPACE MATCHES "^(.*)::\$")
      set(CRES_NAMESPACE "${CMAKE_MATCH_1}")
    endif()
    message(VERBOSE "export set ${EXPORT_SET} mapped to namespace ${CRES_NAMESPACE}")
    set(CETMODULES_NAMESPACE_EXPORT_SET_${EXPORT_SET}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
      ${CRES_NAMESPACE} CACHE INTERNAL
      "Namespace for export set ${EXPORT_SET} of project ${CETMODULES_CURRENT_PROJECT_NAME}")
  elseif (NOT CRES_NO_REDEFINE)
    if (CRES_NAMESPACE)
      message(WARNING "attempt to set namespace for existing export set ${EXPORT_SET} (currently \"${CETMODULES_NAMESPACE_EXPORT_SET_${EXPORT_SET}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}}\") ignored")
    endif()
    message(VERBOSE "Lowering the dependency precedence of existing export set ${EXPORT_SET}")
    set_property(CACHE CETMODULES_EXPORT_SETS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
      APPEND PROPERTY VALUE "${EXPORT_SET}")
  endif()
  if (CRES_SET_VAR)
    set(${CRES_SET_VAR} ${EXPORT_SET} PARENT_SCOPE)
  endif()
  if (CRES_NAMESPACE_VAR)
    set(${CRES_NAMESPACE_VAR} ${CETMODULES_NAMESPACE_EXPORT_SET_${EXPORT_SET}_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}} PARENT_SCOPE)
  endif()
  if (CRES_SET_DEFAULT AND CRES_SET_NAME)
    set(${CETMODULES_CURRENT_PROJECT_NAME}_DEFAULT_EXPORT_SET ${EXPORT_SET} PARENT_SCOPE)
  endif()
endfunction()
