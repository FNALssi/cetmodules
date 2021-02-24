include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetCMakeUtils)
include(FindPackageHandleStandardArgs)

macro(cet_find_pkg_config_package)
  cet_passthrough(FLAG KEYWORD QUIET PACKAGE_FIND_QUIETLY _cet_find_pkg_config_package_quiet)
  cet_passthrough(FLAG KEYWORD REQUIRED PACKAGE_FIND_REQUIRED _cet_find_pkg_config_package_required)
  set(_cet_find_pkg_config_pkg_prefix ${CMAKE_FIND_PACKAGE_NAME})
  find_package(PkgConfig REQUIRED QUIET)
  set(CMAKE_FIND_PACKAGE_NAME ${_cet_find_pkg_config_pkg_prefix})
  unset(_cet_find_pkg_config_pkg_prefix)
  set(_cet_find_pkg_config_package_vexpr)
  if (PACKAGE_FIND_VERSION_RANGE)
    if (PACKAGE_FIND_VERSION_RANGE_MIN STREQUAL "INCLUDE")
      string(APPEND _cet_find_pkg_config_package_vexpr ">=${PACKAGE_FIND_VERSION_MIN}")
    else()
      string(APPEND _cet_find_pkg_config_package_vexpr ">${PACKAGE_FIND_VERSION_MIN")
    endif()
    if (PACKAGE_FIND_VERSION_RANGE_MAX STREQUAL "INCLUDE")
      string(APPEND _cet_find_pkg_config_package_vexpr "<=${PACKAGE_FIND_VERSION_MAX}")
    else()
      string(APPEND _cet_find_pkg_config_package_vexpr "<${PACKAGE_FIND_VERSION_MAX}")
    endif()
  elseif (PACKAGE_FIND_VERSION)
    if (PACKAGE_FIND_EXACT)
      string(APPEND _cet_find_pkg_config_package_vexpr "=${PACKAGE_FIND_VERSION}")
    else()
      string(APPEND _cet_find_pkg_config_package_vexpr ">=${PACKAGE_FIND_VERSION}")
    endif()
  endif()
  set(_cet_find_pkg_config_package_modules "${ARGN}")
  list(TRANSFORM _cet_find_pkg_config_package_modules
    APPEND "${_cet_find_pkg_config_package_vexpr}")

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

  unset(_cet_find_pkg_config_package_quiet)
  unset(_cet_find_pkg_config_package_required)
  unset(_cet_find_pkg_config_package_vexpr)
  unset(_cet_find_pkg_config_package_modules)
endmacro()

cmake_policy(POP)
