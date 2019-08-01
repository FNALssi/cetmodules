include(CetFindPackage)
include(Compatibility)
include(ParseVersionString)

macro(find_ups_product)
  warn_deprecated("find_ups_product(${ARGV0})"
    " - use cet_find_package() and standard target notation to track \
transitive dependencies.\
")
  _parse_fup_arguments(${ARGN})
  if (NOT _FUP_PROJECT)
    product_to_project(${_FUP_PRODUCT} _FUP_PROJECT ${_FUP_PREFIX})
  endif()
  if (_FUP_PROJECT) # Yay!
    if (_FUP_PRODUCT IN_LIST
        ${PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES AND NOT "PRIVATE"
        IN_LIST _FUP_UNPARSED_ARGUMENTS)
      list(APPEND _FUP_UNPARSED_ARGUMENTS PRIVATE)
      message(VERBOSE "requested product ${_FUP_PRODUCT} is build-only, omitting from transitive dependencies")
    endif()
    unset(reset_disable)
    if (_FUP_DISABLED AND NOT CMAKE_DISABLE_FIND_PACKAGE_${_FUP_PROJECT})
      # If we didn't have a UPS package set up, don't try to find
      # something else.
      set(CMAKE_DISABLE_FIND_PACKAGE_${_FUP_PROJECT} TRUE)
      set(reset_disable TRUE)
    endif()
    # Since we're asking for a UPS package old-style, we will enable it
    # to define old-style all-caps environment variables for appropriate
    # targets.
    set(${PROJECT_NAME}_OLD_STYLE_CONFIG_VARS TRUE)
    # Find the package.
    cet_find_package(${_FUP_PROJECT} ${_FUP_DOT_VERSION} ${_FUP_UNPARSED_ARGUMENTS})
    # Reset to cached value.
    set(${PROJECT_NAME}_OLD_STYLE_CONFIG_VARS
      $CACHE{${PROJECT_NAME}_OLD_STYLE_CONFIG_VARS})
    # Restore CMAKE_DISABLE_FIND_PACKAGE in case someone wants to try
    # again e.g. without UPS.
    if (reset_disable)
      unset(CMAKE_DISABLE_FIND_PACKAGE_${_FUP_PROJECT})
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
          if (TARGET ${target})
            set(${_FUP_PRODUCT_UC} ${target})
            break()
          endif()
        endforeach()
      endif()
      if (NOT ${_FUP_PRODUCT_UC})
        if (${_FUP_PRODUCT}_LIBRARY)
          set(${_FUP_PRODUCT_UC} "${${_FUP_PRODUCT}_LIBRARY}")
        elseif (${_FUP_PRODUCT}_LIBRARIES)
          set(${_FUP_PRODUCT_UC} "${${_FUP_PRODUCT}_LIBRARIES}")
        endif()
      endif()
      if (${_FUP_PRODUCT_UC} AND NOT CACHED{${_FUP_PRODUCT_UC}})
        set(${_FUP_PRODUCT_UC} "${${_FUP_PRODUCT_UC}}"
          CACHE FILEPATH "Primary library for UPS product ${_FUP_PRODUCT}")
      endif()
    else()
      set(${_FUP_PRODUCT}_FOUND FALSE)
      set(${_FUP_PRODUCT_UC}_FOUND FALSE)
    endif()
  elseif (_FUP_DISABLED)
    set(${_FUP_PRODUCT}_FOUND FALSE)
    set(${_FUP_PRODUCT_UC}_FOUND FALSE)
    set(${_FUP_PRODUCT_UC} ${FUP_PRODUCT_UC}-NOTFOUND)
  else()
    # We're stretching: try to find a suitably-named library.
    find_library(${_FUP_PRODUCT_UC}
      NAMES ${_FUP_PRODUCT} ${_FUP_PRODUCT_UC} ${_FUP_PRODUCT_LC}
      HINTS ${_FUP_PREFIX})
    if (${_FUP_PRODUCT_UC})
      set(${_FUP_PRODUCT}_FOUND TRUE)
      set(${_FUP_PRODUCT_UC}_FOUND TRUE)
      set(${_FUP_PRODUCT}_LIBRARY ${${_FUP_PRODUCT_UC}})
      set(${_FUP_PRODUCT}_LIBRARIES ${${_FUP_PRODUCT_UC}})
      get_filename_component(${_FUP_PRODUCT}_LIBRARY_DIR
        "${${_FUP_PRODUCT}_LIBRARY}" DIRECTORY CACHE)
    endif()
    # Now try to find a suitable include directory.
    foreach (_fup_env_suffix IN ITEMS INC INCDIR INC_DIR INCLUDE_DIR)
      if (DEFINED ENV{${_FUP_PRODUCT_UC}_${_fup_env_suffix}} AND
          IS_DIRECTORY "$ENV{${_FUP_PRODUCT_UC}_${_fup_env_suffix}}")
        set(${_FUP_PRODUCT}_INCLUDE_DIR
          "$ENV{${_FUP_PRODUCT_UC}_${_fup_env_suffix}}")
        set(${_FUP_PRODUCT}_INCLUDE_DIRS
          "$ENV{${_FUP_PRODUCT_UC}_${_fup_env_suffix}}")
        break()
      endif()
    endforeach()
  endif()
  # Set include directories for backward compatibility, if we can.
  set(_fup_include_candidates)
  if (NOT (_FUP_INTERFACE OR _FUP_INCLUDED_${_FUP_PROJECT}))
    if (TARGET ${${_FUP_PRODUCT_UC}}) # Maybe the target can tell us.
      get_property(_fup_include_candidates TARGET ${${_FUP_PRODUCT_UC}}
        PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
    endif()
    list(APPEND _fup_include_candidates ${${_FUP_PRODUCT}_INCLUDE_DIRS}
      ${${_FUP_PRODUCT}_INCUDE_DIR})
    foreach (_fup_incdir
        IN LISTS _fup_include_candidates)
      if (IS_DIRECTORY "${_fup_incdir}")
        list(APPEND _fup_include_candidates "${_fup_incdir}")
      endif()
    endforeach()
    list(REMOVE_DUPLICATES _fup_include_candidates)
    if (_fup_include_candidates)
      include_directories(${_fup_include_candidates})
      set(_FUP_INCLUDED_${_FUP_PROJECT} TRUE)
    endif()
  endif()
endmacro()

# Attempt to ascertain the correct project name for a product.
function(product_to_project PRODUCT PROJECT_VAR)
  string(TOLOWER "${PRODUCT}" PRODUCT_LC)
  string(TOUPPER "${PRODUCT}" PRODUCT_UC)
  set(module_bases
    ${cetmodules_BIN_DIR}/../Modules/compat
    ${cetmodules_BIN_DIR}/../Modules
    ${CMAKE_ROOT}/Modules)
  # Split into three by likelihood of success to cut down on unnecessary
  # GLOBbing.
  foreach (base_list IN ITEMS ARGN module_bases CMAKE_PREFIX_PATH)
    set(candidates)
    _config_candidates(config_candidates ${${base_list}})
    foreach (candidate IN LISTS config_candidates)
      if (candidate MATCHES
          "(^|/)((lib(64)?|share)/([^/]+)/(cmake/)?)?(([^/]+)Config|Find([^/]+)|[^/]+-config)\.cmake$" OR
          candidate MATCHES
          "(^|/)((lib(64)?|share)/(cmake/)?([^/]+)/)?(([^/]+)Config|Find([^/]+)|[^/]+-config)\.cmake$")
        list(APPEND candidates # In order of preference.
          ${CMAKE_MATCH_8} ${CMAKE_MATCH_9} ${CMAKE_MATCH_6})
      endif()
    endforeach()
    list(REMOVE_DUPLICATES candidates)
    list(TRANSFORM candidates TOLOWER OUTPUT_VARIABLE candidates_lc)
    # Find the first case-insensitive match.
    list(FIND candidates_lc "${PRODUCT_LC}" idx)
    if (idx GREATER -1)
      list(GET candidates ${idx} result)
      set(${PROJECT_VAR} ${result} PARENT_SCOPE)
      return()
    endif()
  endforeach()
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
