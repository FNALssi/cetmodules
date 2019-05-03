########################################################################
# cet_project_var(VAR_NAME [OPTIONS] [INITIAL_VALUE]...)
#
# Set a cached project variable ${CMAKE_PROJECT_NAME}_${VARNAME}and add
# it to the cached list CET_PROJECT_VARS.
#
# Cached variables will be added to the CMakeConfig.cmake file and
# available in dependent packages. In this context, relative PATH and
# FILEPATH variables will be made absolute by appending to
# ${PACKAGE_PREFIX}.
#
#
# OPTIONS:
#
#   DOCSTRING <string>
#
#    A string describing the variable (defaults to a generic
#    description).
#
#   EMPTY_OK
#
#    If true, an empty or invalid value for this variable is acceptable.
#
#   MISSING_OK
#
#    If true, a value not representing a valid path in the installation
#    area is acceptable -- meaningful only for PATH and FILEPATH types.
#
#   TYPE
#
#    The type of the cached variable (defaults to PATH).
#
########################################################################
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_policy(VERSION 3.3) # For if (IN_LIST)


function(cet_project_var VAR_NAME)
  cmake_parse_arguments(CPV "EMPTY_OK;MISSING_OK" "DOCSTRING;TYPE" "" ${ARGN})
  if (NOT VAR_NAME IN_LIST ${CMAKE_PROJECT_NAME}_VARS)
    set(${CMAKE_PROJECT_NAME}_VARS ${${CMAKE_PROJECT_NAME}_VARS} ${VAR_NAME}
      CACHE INTERNAL "List of valid project variables")
  endif()
  if (NOT CPV_DOCSTRING)
    set(CPV_DOCSTRING "Project's setting for ${VAR_NAME}")
  endif()
  if (NOT CPV_TYPE)
    set(CPV_TYPE "PATH")
  endif()
  if (DEFINED ${VAR_NAME})
    set(${CMAKE_PROJECT_NAME}_${VAR_NAME} ${${VAR_NAME}}
    CACHE ${CPV_TYPE} ${CPV_DOCSTRING})
  elseif (CPV_UNPARSED_ARGUMENTS)
    set(${CMAKE_PROJECT_NAME}_${VAR_NAME} ${CPV_UNPARSED_ARGUMENTS}
      CACHE ${CPV_TYPE} ${CPV_DOCSTRING})
  endif()
  if (NOT (${CMAKE_PROJECT_NAME}_${VAR_NAME} OR ${CPV_EMPTY_OK}))
    message(FATAL_ERROR "cet_project_var: attempt to set project variable ${CMAKE_PROJECT_NAME}_${VAR_NAME} to empty or invalid value \"${{CMAKE_PROJECT_NAME}_{${VAR_NAME}}\"")
  endif()
  if (CPV_TYPE STREQUAL "PATH" OR
      CPV_TYPE STREQUAL "FILEPATH")
    if (CPV_EMPTY_OK OR CPV_MISSING_OK)
      set(clause "if (EXISTS \"@PACKAGE_${VAR_NAME}@\");  set(${CMAKE_PROJECT_NAME}_${VAR_NAME} \"@PACKAGE_${VAR_NAME}@\");endif()")
    else()
      set(clause "set_and_check(${CMAKE_PROJECT_NAME}_${VAR_NAME} \"@PACKAGE_${VAR_NAME}@\")")
    endif()
  else()
    if (CPV_MISSING_OK)
      message(WARNING "cet_project_var ignoring MISSING_OK option for non-path variable ${CMAKE_PROJECT_NAME}_${VAR_NAME} of type ${CPV_TYPE}")
    endif()
    set(clause "set(${CMAKE_PROJECT_NAME}_${VAR_NAME} \"@${CMAKE_PROJECT_NAME}_${VAR_NAME}@\")")
  endif()
  set(${CMAKE_PROJECT_NAME}_DEFINITIONS_LIST ${${CMAKE_PROJECT_NAME}_DEFINITIONS_LIST} ${clause}
    CACHE INTERNAL "Project variable definitions")
endfunction()

cmake_policy(POP)
