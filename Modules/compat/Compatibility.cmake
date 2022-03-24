#[================================================================[.rst:
X
=
#]================================================================]
########################################################################
# Compatibility functions and macros to aid migration from
# cetbuildtools.
#
########################################################################

# Avoid unwanted repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetCMakeUtils)
include(CetRegexEscape)

set(CET_WARN_DEPRECATED TRUE)

function(warn_deprecated OLD)
  if (NOT CET_WARN_DEPRECATED)
    return()
  endif()
  cmake_parse_arguments(PARSE_ARGV 1 WD "" "NEW;SINCE" "")
  if (WD_NEW)
    set(msg " - use ${WD_NEW} instead")
  endif()
  if (NOT DEFINED WD_SINCE OR "SINCE" IN_LIST WD_KEYWORDS_MISSING_VALUES)
    set(WD_SINCE "cetmodules 2.10")
  endif()
  if (NOT "${WD_SINCE}" STREQUAL "")
    string(PREPEND WD_SINCE " since ")
  endif()
  message(DEPRECATION "${OLD} is deprecated" "${WD_SINCE}"
    ${msg} ${WD_UNPARSED_ARGUMENTS})
endfunction()

foreach (_cet_stem IN ITEMS inc lib build)
  cmake_language(EVAL CODE "function(_cet_check_${_cet_stem}_directory)
    warn_deprecated(\"_cet_check_${_cet_stem}_directory()\" \" - remove\")
  endfunction()\
")
endforeach()

function(cet_add_to_library_list)
  warn_deprecated("add_to_library_list() (with add_library())" NEW "cet_make_library()")
  cet_register_export_set(SET_VAR export_set NAMESPACE_VAR namespace)
  foreach (target IN LISTS ARGN)
    add_library(${namespace}::${target} ALIAS ${target})
  endforeach()
  _add_to_exported_targets(EXPORT_SET ${export_set} TARGETS ${ARGN})
  install(TARGETS ${target} EXPORT ${export_set})
endfunction()

function(cet_checkpoint_cmp)
  set(CETMODULES_CMAKE_MODULE_PATH_CHECKPOINT_VALUE "${CMAKE_MODULE_PATH}"
    CACHE INTERNAL "Propagate CMAKE_MODULE_PATH additions between subprojects")
  set(CETMODULES_CMAKE_MODULE_PATH_CHECKPOINT_PROJECT "${CETMODULES_CURRENT_PROJECT_NAME}"
    CACHE INTERNAL "Project name for previous CMAKE_MODULE_PATH checkpoint")
endfunction()

function(cet_process_cmp)
  get_property(CURRENT_PROJECT CACHE
    CETMODULES_CMAKE_MODULE_PATH_CHECKPOINT_PROJECT PROPERTY VALUE)
  if (CACHE{CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${CURRENT_PROJECT}})
    # Already done: don't need to duplicate.
    return()
  endif()
  get_property(extra_dirs
    CACHE CETMODULES_CMAKE_MODULE_PATH_CHECKPOINT_VALUE PROPERTY VALUE)
  list(REMOVE_ITEM extra_dirs ${CMAKE_MODULE_PATH})
  cet_regex_escape("${${CURRENT_PROJECT}_SOURCE_DIR}" e_srcdir)
  list(FILTER extra_dirs INCLUDE REGEX "^${e_srcdir}")
  if (extra_dirs)
    cet_cmake_module_directories("${extra_dirs}" PROJECT ${CURRENT_PROJECT})
  endif()
  cet_checkpoint_cmp()
endfunction()

function(cet_checkpoint_did)
  get_property(did DIRECTORY PROPERTY INCLUDE_DIRECTORIES)
  set(CETMODULES_DIRECTORY_INCLUDE_DIRECTORIES_CHECKPOINT_VALUE "${did}"
    CACHE INTERNAL "Propagate directory-scope INCLUDE_DIRECTORIES additions between subprojects")
  set(CETMODULES_DIRECTORY_INCLUDE_DIRECTORIES_CHECKPOINT_PROJECT "${CETMODULES_CURRENT_PROJECT_NAME}"
    CACHE INTERNAL "Project name for previous INCLUDE_DIRECTORIES checkpoint")
endfunction()

function(cet_process_did)
  get_property(CURRENT_PROJECT CACHE
    CETMODULES_DIRECTORY_INCLUDE_DIRECTORIES_CHECKPOINT_PROJECT PROPERTY VALUE)
  get_property(inc_dirs
    CACHE CETMODULES_DIRECTORY_INCLUDE_DIRECTORIES_CHECKPOINT_VALUE PROPERTY VALUE)
  cet_regex_escape("${${CURRENT_PROJECT}_SOURCE_DIR}" e_srcdir)
  list(FILTER inc_dirs INCLUDE REGEX "^${e_srcdir}")
  get_property(current_dirs DIRECTORY PROPERTY INCLUDE_DIRECTORIES)
  list(APPEND inc_dirs ${current_dirs})
  list(REMOVE_DUPLICATES inc_dirs)
  set_property(DIRECTORY PROPERTY INCLUDE_DIRECTORIES "${inc_dirs}")
  cet_checkpoint_did()
endfunction()

function(cet_lib_alias LIB_TARGET)
  warn_deprecated(cet_lib_alias NEW "namespaced target nomenclature for linking to ${LIB_TARGET}")
  foreach (alias IN LISTS ARGN)
    add_custom_command(TARGET ${LIB_TARGET} POST_BUILD
      COMMAND ln -sf $<TARGET_LINKER_FILE_NAME:${LIB_TARGET}>
      $<TARGET_PROPERTY:${LIB_TARGET},LIBRARY_OUTPUT_DIRECTORY>/${CMAKE_SHARED_LIBRARY_PREFIX}${alias}${CMAKE_SHARED_LIBRARY_SUFFIX}
      COMMENT "Generate / refresh courtesy link ${CMAKE_SHARED_LIBRARY_PREFIX}${alias}${CMAKE_SHARED_LIBRARY_SUFFIX} -> $<TARGET_LINKER_FILE_NAME:${LIB_TARGET}>"
      VERBATIM)
  endforeach()
endfunction()

function(cet_find_library VAR)
  warn_deprecated(cet_find_library
    "\nNOTE: prefer find_package() with a custom Findxxx.cmake \
from CMake (see ${CMAKE_ROOT}/Modules or \
https://cmake.org/cmake/help/v${CMAKE_MAJOR_VERSION}.\
${CMAKE_MINOR_VERSION}/manual/cmake-modules.7.html#find-modules) or \
from cetmodules (see ${CMAKE_CURRENT_FUNCTION_DIR}{,/compat}/Find*.cmake)\
")
  find_library(${ARGV})
  if (${VAR})
    _cet_add_transitive_dependency(cet_find_library "${ARGV}")
  endif()
endfunction(cet_find_library)

macro(set_install_root)
  warn_deprecated("set_install_root()" " and should be removed as redundant")
endmacro()

function(_parse_fup_arguments _FUP_PRODUCT)
  # Parse for options we expect.
  set(opts BUILD_ONLY EXPORT INTERFACE PRIVATE OPTIONAL PUBLIC REQUIRED)
  set(sargs PROJECT)
  set(largs)
  foreach (var IN LISTS opts sargs largs
      ITEMS -- _OPTS _SARGS _LARGS DOT_VERSION UPS_VERSION VERSION
      UNPARSED_ARGUMENTS KEYWORDS_MISSING_VALUES)
    unset(_FUP_${var})
    unset(_FUP_${var} PARENT_SCOPE)
  endforeach()
  cmake_parse_arguments(PARSE_ARGV 1 _FUP
    "${opts}" "${sargs}" "--;_OPTS;_SARGS;_LARGS;${largs}")
  foreach (var IN LISTS _FUP__OPTS _FUP__SARGS _FUP__LARGS)
    unset(_FUP_${var})
    unset(_FUP_${var} PARENT_SCOPE)
  endforeach()
  # Parse for options we were told to expect first time.
  cmake_parse_arguments(_FUP "${_FUP__OPTS}" "${_FUP__SARGS}" "${_FUP__LARGS}" ${_FUP_UNPARSED_ARGUMENTS})
  foreach (vis IN ITEMS BUILD_ONLY INTERFACE PRIVATE PUBLIC EXPORT)
    cet_passthrough(FLAG IN_PLACE _FUP_${vis})
  endforeach()
  if (_FUP_OPTIONAL AND _FUP_REQUIRED)
    message(FATAL_ERROR "find_ups_product(): OPTIONAL and REQUIRED are mutually exclusive")
  endif()
  if (_FUP_REQUIRED OR NOT _FUP_OPTIONAL)
    set(_FUP_REQUIRED REQUIRED)
  else()
    unset(_FUP_REQUIRED)
  endif()
  list(APPEND _FUP_-- ${_FUP_REQUIRED} ${_FUP_INTERFACE} ${_FUP_PRIVATE} ${_FUP_PUBLIC})
  if (_FUP_UNPARSED_ARGUMENTS AND "${_FUP_UNPARSED_ARGUMENTS}" MATCHES "^v[^ \t\n]+")
    list(POP_FRONT _FUP_UNPARSED_ARGUMENTS _FUP_VERSION)
    to_cmake_version(${_FUP_VERSION} _FUP_DOT_VERSION)
    to_ups_version(${_FUP_VERSION} _FUP_UPS_VERSION)
  endif()
  if (_FUP_--)
    list(APPEND _FUP_UNPARSED_ARGUMENTS ${_FUP_--})
  endif()
  string(TOUPPER "${_FUP_PRODUCT}" _FUP_PRODUCT_UC)
  string(TOLOWER "${_FUP_PRODUCT}" _FUP_PRODUCT_LC)

  unset(_FUP_PREFIX)
  unset(_FUP_DISABLED)
  if (WANT_UPS AND NOT (DEFINED ENV{SETUP_${_FUP_PRODUCT_UC}} OR
        DEFINED ENV{${_FUP_PRODUCT_UC}_DIR}))
    if (_FUP_OPTIONAL)
      # If WANT_UPS is set, we don't want to accidentally pick up a
      # non-UPS version, but we will want to call find_package
      # anyway to make sure e.g. ${_FUP_PRODUCT}_FOUND is set and
      # other variables are cleared.
      set(_FUP_DISABLED)
    else()
      message(WARNING "find_ups_product(): REQUIRED UPS product ${_FUP_PRODUCT} has not been set up with WANT_UPS == TRUE!")
    endif()
  endif()
  foreach (var IN ITEMS FQ_DIR BASE BASE_DIR ROOT)
    if (DEFINED ENV{${_FUP_PRODUCT_UC}_${var}} AND
        IS_ABSOLUTE "$ENV{${_FUP_PRODUCT_UC}_${var}}" AND
        IS_DIRECTORY "$ENV{${_FUP_PRODUCT_UC}_${var}}")
      list(APPEND _FUP_PREFIX "$ENV{${_FUP_PRODUCT_UC}_${var}}")
    endif()
  endforeach()
  foreach (var IN ITEMS LIB LIB_DIR INC INCDIR INC_DIR INCLUDE_DIR)
    if (DEFINED ENV{${_FUP_PRODUCT_UC}_${var}} AND
        IS_ABSOLUTE "$ENV{${_FUP_PRODUCT_UC}_${var}}" AND
        IS_DIRECTORY "$ENV{${_FUP_PRODUCT_UC}_${var}}")
      get_filename_component(tmp "$ENV{${_FUP_PRODUCT_UC}_${var}}"
        DIRECTORY)
      list(APPEND _FUP_PREFIX "${tmp}")
    endif()
  endforeach()
  foreach (var IN ITEMS UPS_DIR DIR)
    if (DEFINED ENV{${_FUP_PRODUCT_UC}_${var}} AND
        IS_ABSOLUTE "$ENV{${_FUP_PRODUCT_UC}_${var}}" AND
        IS_DIRECTORY "$ENV{${_FUP_PRODUCT_UC}_${var}}")
      list(APPEND _FUP_PREFIX "$ENV{${_FUP_PRODUCT_UC}_${var}}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _FUP_PREFIX)
  foreach (var IN LISTS opts _FUP__OPTS sargs _FUP__SARGS largs _FUP__LARGS
      ITEMS DISABLED DOT_VERSION KEYWORDS_MISSING_VALUES PREFIX PRODUCT
      PRODUCT_LC PRODUCT_UC PROJECT REQUIRED UNPARSED_ARGUMENTS UPS_VERSION
      VERSION)
    if (DEFINED _FUP_${var})
      set(_FUP_${var} "${_FUP_${var}}" PARENT_SCOPE)
    else()
      unset(_FUP_${var} PARENT_SCOPE)
    endif()
  endforeach()
  if (_FUP_PREFIX)
    list(PREPEND CMAKE_PREFIX_PATH "${_FUP_PREFIX}")
    list(REMOVE_DUPLICATES CMAKE_PREFIX_PATH)
    set(CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}" PARENT_SCOPE)
  endif()
endfunction()

macro(cet_without_deprecation_warnings _cet_func)
  if (CET_WARN_DEPRECATED)
    set(_cpv_deprecations_disabled TRUE)
    unset(CET_WARN_DEPRECATED)
  endif()
  cmake_language(CALL ${_cet_func} ${ARGN})
  if (_cpv_deprecations_disabled)
    set(CET_WARN_DEPRECATED TRUE)
    unset(_cpv_deprecations_disabled)
  endif()
endmacro()
