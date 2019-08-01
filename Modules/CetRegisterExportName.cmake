include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(cet_register_export_name EXPORT_VAR)
  if (NOT ${EXPORT_VAR})
    set(${EXPORT_VAR} "${PROJECT_NAME}Targets")
    set(${EXPORT_VAR} "${${EXPORT_VAR}}" PARENT_SCOPE)
  endif()
  set(EXPORT_NAME "${${EXPORT_VAR}}")
  if ("${EXPORT_NAME}" IN_LIST CETMODULES_EXPORT_NAMES_PROJECT_${PROJECT_NAME})
    return()
  endif()
  if (NOT DEFINED CACHE{CETMODULES_EXPORT_NAMES_PROJECT_${PROJECT_NAME}})
    set(CETMODULES_EXPORT_NAMES_PROJECT_${PROJECT_NAME} "${EXPORT_NAME}"
      CACHE INTERNAL "List of export names for ${PROJECT_NAME}")
  else()
    set_property(CACHE CETMODULES_EXPORT_NAMES_PROJECT_${PROJECT_NAME}
      APPEND PROPERTY VALUE "${EXPORT_NAME}")
  endif()
  list(POP_FRONT ARGN default_namespace)
  if (NOT default_namespace)
    set(default_namespace ${${PROJECT_NAME}_NAMESPACE})
  endif()
  project_variable(${EXPORT_NAME}_NAMESPACE ${default_namespace} TYPE STRING CONFIG
    DOCSTRING "Namespace for export name ${EXPORT_NAME} of project ${PROJECT_NAME}")
endfunction()

cmake_policy(POP)
