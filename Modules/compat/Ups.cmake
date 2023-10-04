#[================================================================[.rst:
X
-
#]================================================================]
########################################################################
# Ups.cmake
#
# This CMake file should *not* be included directly by anyone: the CMake
# variable WANT_UPS should be set and the cet_cmake_env() function
# called in order to activate UPS functionality.
#
# Behavior configured via setup_for_development should be incorporated
# into the build configuration via command-line -D (definition) options
# to CMake. It is *strongly* recommended that this task be delegated to
# buildtool, which will add the necessary options to the CMake
# invocation automatically.
#
####################################
# Command-line (cached) CMake variables:
#
#   <cmake_project_name>_UPS_PRODUCT_NAME:STRING=<product_name>
#
#     Specify the UPS product name. Defaults to UPS_PRODUCT_NAME (see
#     below), falls back to the lower-case "safe" representation of
#     CETMODULES_CURRENT_PROJECT_NAME.
#
#   <cmake_project_name>_UPS_QUALIFIER_STRING:STRING=<qual>[:<qual>]...
#
#     Specify the `:'-delimited UPS qualifier string.
#
#   <cmake_project_name>_UPS_PRODUCT_FLAVOR:STRING=<flavor>
#
#     The UPS flavor for the product (NULL or the output of ups flavor).
#
#   UPS_<LANG>_COMPILER_ID:STRING=<id>
#
#     Specify the expected value of CMAKE_<LANG>_COMPILER_ID for the
#     purpose of verification.
#
#   UPS_<LANG>_COMPILER_VERSION:STRING=<id>
#
#     Specify the expected value of CMAKE_<LANG>_COMPILER_VERSION for
#     the purpose of verification.
#
#   UPS_TAR_DIR:PATH=${CMAKE_BINARY_DIR}
#
#     The destination directory for binary archives of UPS products.
#
########################################################################

# Avoid unwanted repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(ParseUpsVersion)
include(ParseVersionString)
include(ProjectVariable)

macro(_ups_init)
  # Define UPS-specific variables.
  _ups_set_variables()

  if (WANT_UPS)
    include(ProcessUpsFiles)
    _ups_product_prep()
  endif()

  # Avoid warning messages for unused variables defined on the command
  # line by buildtool.
  _ups_use_maybe_unused()
endmacro()

macro(_ups_set_variables)
  ##################
  # UPS product name.
  string(TOLOWER "${CETMODULES_CURRENT_PROJECT_NAME}" _usv_default_product_name)
  string(REGEX REPLACE [=[[^a-z0-9]]=] "_" _usv_default_product_name
    "${_usv_default_product_name}")
  project_variable(UPS_PRODUCT_NAME "${_usv_default_product_name}" TYPE STRING DOCSTRING
    "UPS product name for CMake project ${CETMODULES_CURRENT_PROJECT_NAME}")
  unset(_usv_default_product_name)

  set(UPS_${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}_CMAKE_PROJECT_NAME
    ${CETMODULES_CURRENT_PROJECT_NAME} CACHE STRING
    "CMake project name for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")

  ##################
  # UPS product version.
  to_ups_version("${${CETMODULES_CURRENT_PROJECT_NAME}_CMAKE_PROJECT_VERSION_STRING}" _usv_default_ups_version)
  to_ups_version("${PROJECT_VERSION}" _usv_backup_default_ups_version)

  project_variable(UPS_PRODUCT_VERSION "${_usv_default_ups_version}"
    BACKUP_DEFAULT "${usv_backup_default_ups_version}" TYPE STRING DOCSTRING
    "Version for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")

  if ("${_usv_default_ups_version}${_usv_backup_default_ups_version}" STREQUAL "")
    if ("${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}" STREQUAL "")
      message(SEND_ERROR "unable to ascertain a UPS product version for CMake project ${CETMODULES_CURRENT_PROJECT_NAME}")
    else()
      _cet_set_version_from_ups(${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION})
    endif()
  endif()
  unset(_usv_default_ups_version)
  unset(_usv_backup_default_ups_version)

  ##################
  # UPS chains.
  project_variable(UPS_PRODUCT_CHAINS TYPE STRING DOCSTRING
    "Chains for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")

  ##################
  # UPS Qualifiers.
  project_variable(UPS_QUALIFIER_STRING TYPE STRING DOCSTRING
    "Qualifer string for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")

  ##################
  # UPS flavor.
  project_variable(UPS_PRODUCT_FLAVOR TYPE STRING DOCSTRING
    "Flavor for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")

  ##################
  # UPS product installation directory.
  project_variable(UPS_PRODUCT_SUBDIR
    "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}"
    DOCSTRING
    "Product installation subdirectory for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")

  ##################
  # UPS table file directory.
  list(APPEND ${CETMODULES_CURRENT_PROJECT_NAME}_ADD_ARCH_DIRS UPS_PRODUCT_TABLE_SUBDIR)
  project_variable(UPS_PRODUCT_TABLE_SUBDIR ups DOCSTRING
    "Table file subdirectory for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")

  ##################
  # UPS version file name.
  string(REPLACE ":" "_" _usv_default_version_file
    "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_QUALIFIER_STRING}")
  string(PREPEND _usv_default_version_file "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_FLAVOR}_")
  project_variable(UPS_PRODUCT_VERSION_FILE ${_usv_default_version_file} TYPE STRING DOCSTRING
    "Version file name for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")
  unset(_usv_default_version_file)

  ##################
  # UPS binary archive destination directory.
  project_variable(UPS_TAR_DIR "${CMAKE_BINARY_DIR}" TYPE PATH DOCSTRING
    "Product archive destination for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")

  ##################
  # Should we configure PYTHONPATH in the table file?
  project_variable(DEFINE_PYTHONPATH TYPE BOOL DOCSTRING
    "Define PYTHONPATH in table file for UPS product ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")
endmacro()

function(_ups_use_maybe_unused)
  get_property(vars DIRECTORY PROPERTY CACHE_VARIABLES)
  list(FILTER vars INCLUDE REGEX
    [[^CMAKE_[^_]+_(COMPILER|STANDARD(_REQUIRED)?|EXTENSIONS|FLAGS)$]])
  foreach (var IN LISTS vars)
    if (${var})
    endif()
  endforeach()
endfunction()
