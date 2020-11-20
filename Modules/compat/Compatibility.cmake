########################################################################
# Compatibility functions and macros to aid migration from
# cetbuildtools.
#
########################################################################

# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetCMakeUtils)
include(CetRegexEscape)
include(ParseVersionString)

set(CET_WARN_DEPRECATED TRUE)

function(warn_deprecated OLD)
  if (NOT CET_WARN_DEPRECATED)
    return()
  endif()
  cmake_parse_arguments(PARSE_ARGV 1 WD "" "NEW" "")
  if (WD_NEW)
    set(msg " - use ${WD_NEW} instead")
  endif()
  message(DEPRECATION "${OLD} is deprecated in cetmodules 2.0+"
    ${msg} ${WD_UNPARSED_ARGUMENTS})
endfunction()

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
  if (${PROJECT_NAME}_QUALIFIER_STRING MATCHES "(^|:)${QUAL}(:|$)")
    set(${OUT_VAR} TRUE PARENT_SCOPE)
  else ()
    set(${OUT_VAR} FALSE PARENT_SCOPE)
  endif()
endfunction()

function(cet_parse_args PREFIX ARGS FLAGS)
  warn_deprecated("cet_parse_args()" NEW "cmake_parse_arguments()")
  cmake_parse_arguments(PARSE_ARGV 3 "${PREFIX}" "${FLAGS}" "" "${ARGS}")
  get_property(vars DIRECTORY PROPERTY VARIABLES)
  list(FILTER vars INCLUDE REGEX "^${PREFIX}_")
  foreach (var IN LISTS vars)
    set(${var} "${${var}}" PARENT_SCOPE)
  endforeach()
  if (${PREFIX}_UNPARSED_ARGUMENTS)
    set(${PREFIX}_DEFAULT_ARGS "${PREFIX}_UNPARSED_ARGUMENTS}" PARENT_SCOPE)
    unset(${PREFIX}_UNPARSED_ARGUMENTS PARENT_SCOPE)
  endif()
endfunction()

function(set_version_from_ups UPS_VERSION)
  warn_deprecated("set_version_from_ups()" NEW "project(<project-name> VERSION <dot-version>)")
  if (PROJECT_VERSION)
    message(WARNING "specified version ${UPS_VERSION} ignored in favor of CMake-configured ${PROJECT_VERSION}")
  elseif (PROJECT_NAME)
    to_dot_version(${UPS_VERSION} dot_version)
    project(${PROJECT_NAME} VERSION ${dot_version}
      DESCRIPTION ${PROJECT_DESCRIPTION}
      HOMEPAGE_URL ${PROJECT_HOMEPAGE_URL})
  else()
    message(SEND_ERROR "no current project() call to update")
  endif()
endfunction()

function(set_dot_version PRODUCTNAME UPS_VERSION)
  warn_deprecated("set_dot_version()" " - refer to \${PROJECT_NAME}_VERSION instead")
  string(TOUPPER ${PRODUCTNAME} PRODUCTNAME_UC)
  to_dot_version(${UPS_VERSION} tmp)
  if (${PRODUCTNAME_UC}_DOT_VERSION)
    message(WARNING "replacing existing value of ${PRODUCTNAME_UC}_DOT_VERSION (${${PRODUCTNAME_UC}_DOT_VERSION}) with ${tmp}")
  endif()
  set(${PRODUCTNAME_UC}_DOT_VERSION ${tmp} PARENT_SCOPE)
endfunction()

foreach (_cet_stem inc lib build)
  cmake_language(EVAL CODE "function(_cet_check_${_cet_stem}_directory)
    warn_deprecated(\"_cet_check_${_cet_stem}_directory()\" \" - remove\")
  endfunction()\
")
endforeach()

function(cet_add_to_library_list)
  warn_deprecated("add_to_library_list() (with add_library())" NEW "cet_make_library()")
  _calc_namespace(alias_namespace)
  set(export_set)
  cet_register_export_name(export_set)
  foreach (target ${ARGN})
    add_library(${alias_namespace}::${target} ALIAS ${target})
  endforeach()
  _add_to_exported_targets(EXPORT ${export_set} TARGETS ${ARGN})
  install(TARGETS ${target} EXPORT ${export_set})
endfunction()

function(cet_checkpoint_cmp)
  set(CETMODULES_CMAKE_MODULE_PATH_CHECKPOINT_VALUE "${CMAKE_MODULE_PATH}"
    CACHE INTERNAL "Propagate CMAKE_MODULE_PATH additions between subprojects")
  set(CETMODULES_CMAKE_MODULE_PATH_CHECKPOINT_PROJECT "${PROJECT_NAME}"
    CACHE INTERNAL "Project name for previous CMAKE_MODULE_PATH checkpoint")
endfunction()

function(cet_checkpoint_cmp)
  set(CETMODULES_CMAKE_MODULE_PATH_CHECKPOINT_VALUE "${CMAKE_MODULE_PATH}"
    CACHE INTERNAL "Propagate CMAKE_MODULE_PATH additions between subprojects")
  set(CETMODULES_CMAKE_MODULE_PATH_CHECKPOINT_PROJECT "${PROJECT_NAME}"
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
    CACHE INTERNAL "Propagate CMAKE_MODULE_PATH additions between subprojects")
  set(CETMODULES_DIRECTORY_INCLUDE_DIRECTORIES_CHECKPOINT_PROJECT "${PROJECT_NAME}"
    CACHE INTERNAL "Project name for previous CMAKE_MODULE_PATH checkpoint")
endfunction()

function(cet_process_did)
  get_property(CURRENT_PROJECT CACHE
    CETMODULES_DIRECTORY_INCLUDE_DIRECTORIES_CHECKPOINT_PROJECT PROPERTY VALUE)
  get_property(extra_dirs
    CACHE CETMODULES_DIRECTORY_INCLUDE_DIRECTORIES_CHECKPOINT_VALUE PROPERTY VALUE)
  get_property(current_dirs DIRECTORY PROPERTY INCLUDE_DIRECTORIES)
  list(REMOVE_ITEM extra_dirs ${current_dirs})
  cet_regex_escape("${${CURRENT_PROJECT}_SOURCE_DIR}" e_srcdir)
  list(FILTER extra_dirs INCLUDE REGEX "^${e_srcdir}")
  if (extra_dirs)
    include_directories("${extra_dirs}" PROJECT ${CURRENT_PROJECT})
  endif()
  cet_checkpoint_did()
endfunction()

function(check_ups_version PRODUCT VERSION MINIMUM)
  warn_deprecated("check_ups_version()" NEW "if (X VERSION_cmp Y)...")
  cmake_parse_arguments(PARSE_ARGV 3 CUV "" "PRODUCT_OLDER_VAR;PRODUCT_MATCHES_VAR" "")
  if (NOT (CUV_PRODUCT_OLDER_VAR OR CUV_PRODUCT_MATCHES_VAR))
    message(FATAL_ERROR "at least one of PRODUCT_OLDER_VAR and PRODUCT_MATCHES_VAR is required")
  endif()
  to_dot_version(${VERSION} pv)
  to_dot_version(${MINIMUM} mv)
  if (mv VERSION_GREATER pv)
    if (CUV_PRODUCT_OLDER_VAR)
      set(${CUV_PRODUCT_OLDER_VAR} TRUE PARENT_SCOPE)
    endif()
    if (CUV_PRODUCT_MATCHES_VAR)
      set(${CUV_PRODUCT_MATCHES_VAR} FALSE PARENT_SCOPE)
    endif()
  else()
    if (CUV_PRODUCT_MATCHES_VAR)
      set(${CUV_PRODUCT_MATCHES_VAR} TRUE PARENT_SCOPE)
    endif()
    if (CUV_PRODUCT_OLDER_VAR)
      set(${CUV_PRODUCT_OLDER_VAR} FALSE PARENT_SCOPE)
    endif()
  endif()
endfunction()

function(to_ups_version UPS_VERSION VAR)
  parse_version_string("${UPS_VERSION}" SEP _ tmp)
  set(${VAR} "v${tmp}" PARENT_SCOPE)
endfunction()

function(add_to_library_list)
  warn_deprecated("add_to_library_version()" " - remove call.")
endfunction()

function(cet_lib_alias LIB_TARGET)
  warn_deprecated(cet_lib_alias NEW "namespaced target nomenclature for linking to ${LIB_TARGET}")
  foreach(alias IN LISTS ARGN)
    add_custom_command(TARGET ${LIB_TARGET}
      POST_BUILD
      COMMAND ln -sf $<TARGET_LINKER_FILE_NAME:${LIB_TARGET}>
      $<TARGET_PROPERTY:${LIB_TARGET},LIBRARY_OUTPUT_DIRECTORY>/${CMAKE_SHARED_LIBRARY_PREFIX}${alias}${CMAKE_SHARED_LIBRARY_SUFFIX}
      COMMENT "Generate / refresh courtesy link ${CMAKE_SHARED_LIBRARY_PREFIX}${alias}${CMAKE_SHARED_LIBRARY_SUFFIX} -> $<TARGET_LINKER_FILE_NAME:${LIB_TARGET}>"
      VERBATIM)
  endforeach()
endfunction()

function(cet_find_library)
  warn_deprecated(cet_find_library
    "\nNOTE: prefer cet_find_package() with a custom Findxxx.cmake \
from CMake (see ${CMAKE_ROOT}/Modules or \
https://cmake.org/cmake/help/v${CMAKE_MAJOR_VERSION}.\
${CMAKE_MINOR_VERSION}/manual/cmake-modules.7.html#find-modules) or \
from cetmodules (see ${CMAKE_CURRENT_FUNCTION_DIR}{,/compat}/Find*.cmake)\
")
  find_library(${ARGV})
endfunction(cet_find_library)

function(_parse_fup_arguments _FUP_PRODUCT)
  # Parse for options we expect.
  set(opts BUILD_ONLY INTERFACE PRIVATE OPTIONAL PUBLIC REQUIRED)
  set(sargs PROJECT)
  set(largs)
  foreach (var IN LISTS opts sargs largs
      ITEMS -- _OPTS _SARGS _LARGS DOT_VERSION UPS_VERSION VERSION
      UNPARSED_ARGUMENTS KEWORDS_MISSING_VALUES)
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
  foreach (vis IN ITEMS BUILD_ONLY INTERFACE PRIVATE PUBLIC)
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
  if (_FUP_UNPARSED_ARGUMENTS)
    list(POP_FRONT _FUP_UNPARSED_ARGUMENTS _FUP_VERSION)
    to_dot_version(${_FUP_VERSION} _FUP_DOT_VERSION)
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
      # non-UPS version, but we will want to call cet_find_package
      # anyway to make sure e.g. ${_FUP_PRODUCT}_FOUND is set and
      # other variables are cleared.
      set(_FUP_DISABLED)
    else()
      message(SEND_ERROR "find_ups_product(): REQUIRED UPS product ${_FUP_PRODUCT} has not been set up with WANT_UPS == TRUE!")
    endif()
  else()
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
  endif()
  list(REMOVE_DUPLICATES _FUP_PREFIX)
  foreach (var IN LISTS opts _FUP__OPTS sargs _FUP__SARGS largs _FUP__LARGS
      ITEMS DISABLED DOT_VERSION KEWORDS_MISSING_VALUES PREFIX PRODUCT
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

cmake_policy(POP)
