#[================================================================[.rst:
X
-
#]================================================================]
# Avoid unnecessary repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(Compatibility)
include(ParseVersionString)

# Set up the correspondences for some otherwise problematic packages.
set(UPS_cppunit_CMAKE_PROJECT_NAME CppUnit)
set(UPS_eigen_CMAKE_PROJECT_NAME Eigen3)
set(UPS_range_CMAKE_PROJECT_NAME Range)
set(UPS_smc_compiler_CMAKE_PROJECT_NAME Smc)
set(UPS_sqlite_CMAKE_PROJECT_NAME SQLite3)
set(UPS_tbb_CMAKE_PROJECT_NAME TBB)
set(UPS_xerces_c_CMAKE_PROJECT_NAME XercesC)
# Older (<v10) UPS packages of artg4tk had a broken
# *-config-version.cmake file, so just do what we've always done if
# we're calling find_ups_product():
set(UPS_artg4tk_CMAKE_PROJECT_NAME artg4tk-NOTFOUND)

macro(find_ups_product)
  warn_deprecated("find_ups_product(${ARGV0})"
    " - use find_package() and standard target notation to track \
transitive dependencies.\
")
  _parse_fup_arguments(${ARGN})
  if (NOT _FUP_PROJECT)
    product_to_project(${_FUP_PRODUCT} _FUP_PROJECT ${_FUP_PREFIX})
  endif()
  if (_FUP_PROJECT)
    if (NOT _FUP_INCLUDED_${_FUP_PROJECT})
      if (_FUP_PRODUCT IN_LIST
          ${CETMODULES_CURRENT_PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES AND NOT "PRIVATE"
          IN_LIST _FUP_UNPARSED_ARGUMENTS)
        list(APPEND _FUP_UNPARSED_ARGUMENTS PRIVATE)
        message(VERBOSE "requested product ${_FUP_PRODUCT} is build-only, omitting from transitive dependencies")
      endif()
      if (_FUP_DISABLED AND NOT CMAKE_DISABLE_FIND_PACKAGE_${_FUP_PROJECT})
        # If we didn't have a UPS package set up, don't try to find
        # something else.
        set(CMAKE_DISABLE_FIND_PACKAGE_${_FUP_PROJECT} TRUE)
        set(_fup_reset_disable TRUE)
      else()
        set(_fup_reset_disable)
      endif()
      # Since we're asking for a UPS package old-style, we will enable it
      # to define old-style all-caps environment variables for appropriate
      # targets.
      set(${CETMODULES_CURRENT_PROJECT_NAME}_OLD_STYLE_CONFIG_VARS TRUE)
      # Find the package.
      cet_without_deprecation_warnings(cet_find_package
        ${_FUP_PROJECT} ${_FUP_DOT_VERSION} ${_FUP_UNPARSED_ARGUMENTS})
      # Reset to cached value.
      set(${CETMODULES_CURRENT_PROJECT_NAME}_OLD_STYLE_CONFIG_VARS
        $CACHE{${CETMODULES_CURRENT_PROJECT_NAME}_OLD_STYLE_CONFIG_VARS})
      # Restore CMAKE_DISABLE_FIND_PACKAGE in case someone wants to try
      # again e.g. without UPS.
      if (_fup_reset_disable)
        unset(CMAKE_DISABLE_FIND_PACKAGE_${_FUP_PROJECT})
        unset(_fup_reset_disable)
      endif()
      if (${_FUP_PROJECT}_FOUND)
        if (NOT _FUP_PROJECT STREQUAL _FUP_PRODUCT)
          _transfer_package_vars(${_FUP_PROJECT} ${_FUP_PRODUCT})
        endif()
        if (NOT ${_FUP_PRODUCT_UC})
          foreach (target IN ITEMS ${_FUP_PROJECT}::${_FUP_PROJECT}
              ${_FUP_PROJECT}::${_FUP_PRODUCT_LC}
              ${_FUP_PRODUCT}::${_FUP_PRODUCT}
              ${_FUP_PRODUCT_LC}::${_FUP_PRODUCT_LC})
            if (TARGET "${target}")
              set(${_FUP_PRODUCT_UC} ${target})
              break()
            endif()
          endforeach()
        endif()
        if (NOT ${_FUP_PRODUCT_UC})
          if (${_FUP_PRODUCT}_LIBRARIES)
            set(${_FUP_PRODUCT_UC} "${${_FUP_PRODUCT}_LIBRARIES}")
          elseif (${_FUP_PRODUCT}_LIBRARY)
            set(${_FUP_PRODUCT_UC} "${${_FUP_PRODUCT}_LIBRARY}")
          endif()
        endif()
      else()
        set(${_FUP_PRODUCT}_FOUND FALSE)
        set(${_FUP_PRODUCT_UC}_FOUND FALSE)
      endif()
    endif()
  else()
    if (_FUP_DISABLED)
      set(${_FUP_PRODUCT}_FOUND FALSE)
      set(${_FUP_PRODUCT_UC}_FOUND FALSE)
      set(${_FUP_PRODUCT_UC} ${FUP_PRODUCT_UC}-NOTFOUND)
    else()
      set(_FUP_PROJECT ${_FUP_PRODUCT})
      # We're stretching: at least try to find a suitable include directory.
      foreach (_fup_env_suffix IN ITEMS INC INCDIR INC_DIR INCLUDE_DIR)
        if (DEFINED ENV{${_FUP_PRODUCT_UC}_${_fup_env_suffix}} AND
            IS_DIRECTORY "$ENV{${_FUP_PRODUCT_UC}_${_fup_env_suffix}}")
          set(${_FUP_PRODUCT}_INCLUDE_DIR
            "$ENV{${_FUP_PRODUCT_UC}_${_fup_env_suffix}}")
          set(${_FUP_PRODUCT}_INCLUDE_DIRS
            "$ENV{${_FUP_PRODUCT_UC}_${_fup_env_suffix}}")
          set(${_FUP_PROJECT}_FOUND TRUE)
          break()
        endif()
      endforeach()
    endif()
  endif()
  if (_FUP_PROJECT AND NOT _FUP_INCLUDED_${_FUP_PROJECT} AND
      (${_FUP_PROJECT}_FOUND OR ${_FUP_PRODUCT}_INCLUDE_DIR))
    # Since we're not trying to find lots of different components, if
    # we've found it once, we've found it for this directory scope.
    set(_FUP_INCLUDED_${_FUP_PROJECT} TRUE)
    # Set include directories for backward compatibility, if we can.
    if (NOT ${_FUP_PROJECT}_IN_TREE)
      set(_fup_include_candidates)
      if (${_FUP_PRODUCT_UC} MATCHES "^([^;]+)(;|$)")
        if (TARGET "${CMAKE_MATCH_1}") # Maybe the target can tell us.
          get_property(_fup_include_candidates TARGET "${CMAKE_MATCH_1}"
            PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
        endif()
      endif()
      foreach (_fup_varstub IN ITEMS FQ_DIR DIR)
        if (DEFINED ENV{${_FUP_PRODUCT_UC}_${_fup_varstub}})
          foreach (_fup_incdir IN ITEMS inc include src LISTS _FUP_PROJECT _FUP_PROJECT_LC _FUP_PROJECT_UC)
            if (IS_DIRECTORY "$ENV{${_FUP_PRODUCT_UC}_${_fup_varstub}}/${_fup_incdir}")
              list(APPEND _fup_include_candidates "$ENV{${_FUP_PRODUCT_UC}_${_fup_varstub}}/${_fup_incdir}")
            endif()
          endforeach()
        endif()
      endforeach()
      unset(_fup_varstub)
      list(APPEND _fup_include_candidates ${${_FUP_PRODUCT}_INCLUDE_DIRS}
        ${${_FUP_PRODUCT}_INCLUDE_DIR}
        ${${_FUP_PROJECT}_INCLUDE_DIRS}
        ${${_FUP_PROJECT}_INCLUDE_DIR}
        $ENV{${_FUP_PRODUCT_UC}_INC}
        $ENV{${_FUP_PRODUCT_UC}_INCLUDE})
      set(_fup_include_dirs)
      foreach (_fup_incdir IN LISTS _fup_include_candidates)
        if (IS_DIRECTORY "${_fup_incdir}")
          list(APPEND _fup_include_dirs "${_fup_incdir}")
        endif()
      endforeach()
      list(REMOVE_DUPLICATES _fup_include_dirs)
      list(POP_FRONT _fup_include_dirs _fup_incdir)
      if (_fup_incdir)
        include_directories(${_fup_incdir})
      endif()
    endif()
    # Set other expected variables (again, if we can).
    if (NOT ${_FUP_PRODUCT_UC}_UPS_VERSION)
      if (DEFINED ENV{${_FUP_PRODUCT_UC}_UPS_VERSION})
        set(${_FUP_PRODUCT_UC}_UPS_VERSION $ENV{${_FUP_PRODUCT_UC}_UPS_VERSION})
      elseif (DEFINED ENV{${_FUP_PRODUCT_UC}_VERSION})
        set(${_FUP_PRODUCT_UC}_UPS_VERSION $ENV{${_FUP_PRODUCT_UC}_VERSION})
      else()
        message(WARNING "no UPS version information in environment for product ${_FUP_PRODUCT}")
      endif()
    endif()
    if (NOT ${_FUP_PROJECT}_VERSION)
      to_version_string(${${_FUP_PRODUCT_UC}_UPS_VERSION} ${_FUP_PROJECT}_VERSION)
    endif()
    if (${_FUP_PROJECT}_VERSION AND NOT _FUP_PROJECT STREQUAL _FUP_PRODUCT_UC)
      to_ups_version(${${_FUP_PROJECT}_VERSION} ${_FUP_PRODUCT_UC}_VERSION)
    endif()
  endif()
  unset(_fup_include_candidates)
endmacro()

# Attempt to ascertain the correct project name for a product.
function(product_to_project PRODUCT PROJ_VAR)
  # See if we can preempt:
  if (DEFINED UPS_${PRODUCT}_CMAKE_PROJECT_NAME)
    # If the variable evaluates to TRUE, we're golden; otherwise we've
    # tried before and failed so give up.
    set(${PROJ_VAR} ${UPS_${PRODUCT}_CMAKE_PROJECT_NAME} PARENT_SCOPE)
    return()
  endif()
  string(TOLOWER "${PRODUCT}" PRODUCT_LC)
  string(TOUPPER "${PRODUCT}" PRODUCT_UC)
  set(module_bases
    ${cetmodules_BIN_DIR}/../Modules/compat
    ${cetmodules_BIN_DIR}/../Modules
    ${CMAKE_ROOT}/Modules)
  # Split into three by likelihood of success to cut down on unnecessary
  # GLOBbing.
  foreach (base_list IN ITEMS ARGN module_bases CMAKE_PREFIX_PATH)
    _config_candidates(config_candidates ${${base_list}})
    foreach (candidate IN LISTS config_candidates)
      if (candidate MATCHES
          "(^|/)((lib|lib64|share)/([^/]+)/(cmake/)?)?(([^/]+)Config|Find([^/]+)|([^/]+)-config)\.cmake$")
        set(candidates # In order of preference.
          ${CMAKE_MATCH_7} ${CMAKE_MATCH_8} ${CMAKE_MATCH_9} ${CMAKE_MATCH_4})
      elseif (candidate MATCHES
          "(^|/)((lib|lib64|share)/(cmake/)?([^/]+)/)?(([^/]+)Config|Find([^/]+)|([^/]+)-config)\.cmake$")
        set(candidates
          ${CMAKE_MATCH_7} ${CMAKE_MATCH_8} ${CMAKE_MATCH_9} ${CMAKE_MATCH_5})
      endif()
      list(TRANSFORM candidates TOLOWER OUTPUT_VARIABLE candidates_lc)
      # Find the first case-insensitive match.
      list(FIND candidates_lc "${PRODUCT_LC}" idx)
      if (idx GREATER -1)
        list(GET candidates ${idx} result)
        set(${PROJ_VAR} ${result} PARENT_SCOPE)
        set(UPS_${PRODUCT}_CMAKE_PROJECT_NAME ${result} PARENT_SCOPE)
        return()
      endif()
    endforeach()
  endforeach()
  # Mark our failure so we don't do expensive searches next time around.
  set(UPS_${PRODUCT}_CMAKE_PROJECT_NAME ${PRODUCT}-NOTFOUND PARENT_SCOPE)
endfunction()

function(_config_candidates RESULTS_VAR)
  set(config_globs)
  foreach (base IN LISTS ARGN)
    foreach (subdir IN ITEMS "" "share/*" "share/cmake/*" "share/*/cmake" "lib*/cmake/*" "lib*/*/cmake" "lib*/*")
      foreach (glob IN ITEMS *Config.cmake *-config.cmake Find*.cmake)
        string(JOIN "/" config_glob ${base} ${subdir} ${glob})
        list(APPEND config_globs "${config_glob}")
      endforeach()
    endforeach()
  endforeach()
  if (config_globs)
    file(GLOB ${RESULTS_VAR} FOLLOW_SYLINKS LIST_DIRECTORIES FALSE
      ${config_globs})
  endif()
  set(${RESULTS_VAR} ${${RESULTS_VAR}} PARENT_SCOPE)
endfunction()

function(_transfer_package_vars FROM TO)
  set(vars DIR FIND_COMPONENTS FOUND INCLUDE_DIR INCLUDE_DIRS LIBRARIES LIBRARY VERSION)
  list(TRANSFORM ${FROM}_FIND_COMPONENTS REPLACE "^(.+)$" "FIND_REQUIRED_\\1;\\1_FOUND"
    OUTPUT_VARIABLE component_vars)
  foreach (var IN LISTS vars component_vars)
    if (${FROM}_${var})
      set(${TO}_${var} ${${FROM}_${var}} PARENT_SCOPE)
    endif()
  endforeach()
endfunction()
