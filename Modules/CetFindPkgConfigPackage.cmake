include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 2.8.12...3.19 FATAL_ERROR)

include(FindPackageHandleStandardArgs)

macro(cet_find_pkg_config_package)
  if (${CMAKE_FIND_PACKAGE_NAME}_FIND_QUIETLY)
    set(_cet_find_pkg_config_package_quiet QUIET)
  else()
    set(_cet_find_pkg_config_package_quiet)
  endif()
  if (${CMAKE_FIND_PACKAGE_NAME}_FIND_REQUIRED)
    set(_cet_find_pkg_config_package_required REQUIRED)
  else()
    set(_cet_find_pkg_config_package_required)
  endif()
  set(_cet_find_pkg_config_pkg_prefix ${CMAKE_FIND_PACKAGE_NAME})
  find_package(PkgConfig REQUIRED QUIET)
  set(CMAKE_FIND_PACKAGE_NAME ${_cet_find_pkg_config_pkg_prefix})
  unset(_cet_find_pkg_config_pkg_prefix)
  set(_cet_find_pkg_config_package_vexpr)
  if (${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION_RANGE)
    if (${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION_RANGE_MIN STREQUAL "INCLUDE")
      set(_cet_find_pkg_config_package_vexpr "${_cet_find_pk_config_package_vexpr}<=>=${${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION_MIN}")
    else()
      set(_cet_find_pkg_config_package_vexpr "${_cet_find_pk_config_package_vexpr}<=>${${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION_MIN")
    endif()
    if (${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION_RANGE_MAX STREQUAL "INCLUDE")
      set(_cet_find_pkg_config_package_vexpr "${_cet_find_pk_config_package_vexpr}<=${${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION_MAX}")
    else()
      set(_cet_find_pkg_config_package_vexpr "${_cet_find_pk_config_package_vexpr}<=<${${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION_MAX}")
    endif()
  elseif (${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION)
    if (${CMAKE_FIND_PACKAGE_NAME}_FIND_EXACT)
      set(_cet_find_pkg_config_package_vexpr "${_cet_find_pk_config_package_vexpr}<==${${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION}")
    else()
      set(_cet_find_pkg_config_package_vexpr "${_cet_find_pk_config_package_vexpr}<=>=${${CMAKE_FIND_PACKAGE_NAME}_FIND_VERSION}")
    endif()
  endif()
  set(_cet_find_pkg_config_package_modules)
  foreach (_cet_find_pkg_config_package_module "${ARGN}")
    set(_cet_find_pkg_config_package_modules
      "${_cet_find_pkg_config_package_modules}"
      "${_cet_find_pkg_config_package_module}${_cet_find_pkg_config_package_vexpr}")
  endforeach()
  pkg_search_module(${CMAKE_FIND_PACKAGE_NAME}
    ${_cet_find_pkg_config_package_quiet}
    ${_cet_find_pkg_config_package_required}
    NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH
    IMPORTED_TARGET ${_cet_find_pkg_config_package_modules})
  if (${CMAKE_FIND_PACKAGE_NAME}_FOUND AND
      NOT TARGET ${CMAKE_FIND_PACKAGE_NAME}::${CMAKE_FIND_PACKAGE_NAME})
    add_library(${CMAKE_FIND_PACKAGE_NAME}::${CMAKE_FIND_PACKAGE_NAME}
      ALIAS PkgConfig::${CMAKE_FIND_PACKAGE_NAME})
  endif()

  find_package_handle_standard_args(${CMAKE_FIND_PACKAGE_NAME}
    VERSION_VAR ${CMAKE_FIND_PACKAGE_NAME}_VERSION
    REQUIRED_VARS ${CMAKE_FIND_PACKAGE_NAME}_PREFIX)

  unset(_cet_find_pkg_config_package_module)
  unset(_cet_find_pkg_config_package_modules)
  unset(_cet_find_pkg_config_package_quiet)
  unset(_cet_find_pkg_config_package_required)
  unset(_cet_find_pkg_config_package_vexpr)
endmacro()

cmake_policy(POP)
