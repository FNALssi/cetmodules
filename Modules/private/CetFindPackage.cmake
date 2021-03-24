# Once only!
include_guard(GLOBAL)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.19...3.20 FATAL_ERROR)

set(_cet_find_package_version_supported 3.20)
if ("${CMAKE_VERSION_MAJOR}.${CMAKE_VERSION_MINOR}" VERSION_GREATER
    _cet_find_package_version_supported)
  message(WARNING "unsupported CMake version ${CMAKE_VERSION}.
Contact cetmodules developers to request updated find_package() support")
endif()

include(Compatibility)
include(ParseVersionString)

include(CMakeFindDependencyMacro)
set(_cet_find_package_flags REQUIRED QUIET EXACT)
set(_cet_find_package_flag_vars REQUIRED QUIETLY VERSION_EXACT)

set(_cet_find_package_flags CMAKE_FIND_ROOT_PATH_BOTH CONFIG EXACT QUIET
  MODULE NO_CMAKE_BUILDS_PATH NO_CMAKE_FIND_ROOT_PATH
  NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_PACKAGE_REGISTRY NO_CMAKE_PATH
  NO_CMAKE_SYSTEM_PACKAGE_REGISTRY NO_CMAKE_SYSTEM_PATH NO_DEFAULT_PATH
  NO_PACKAGE_ROOT_PATH NO_MODULE NO_POLICY_SCOPE
  NO_SYSTEM_ENVIRONMENT_PATH ONLY_CMAKE_FIND_ROOT_PATH REQUIRED)
set(_cet_find_package_one_arg_opts)
set(_cet_find_package_args COMPONENTS CONFIGS HINTS NAMES
  OPTIONAL_COMPONENTS PATH_SUFFIXES PATHS)

if (COMMAND _find_package)
  message(FATAL_ERROR "find_package() has already been overridden: cetmodules cannot function")
endif()

# Intercept calls to find_package() for IN_TREE packages and make them
# do the right thing.
macro(find_package PKG)
  cmake_policy(PUSH)
  cmake_minimum_required(VERSION 3.18.2...3.20)
  # Must match accepted argument list of find_package() for latest
  # supported version of CMake.
  cmake_parse_arguments(_cet_fp
    "${_cet_find_package_flags}"
    "${_cet_find_package_one_arg_opts}"
    "${_cet_find_package_args}"
    ${ARGN})

  if (${PKG}_IN_TREE)
    if (NOT CMAKE_DISABLE_FIND_PACKAGE_${PKG} OR
          "${ARGN}" MATCHES "(^|;)REQUIRED(;|$)")
      string(TOUPPER "${PKG}" _fp_PKG_UC)
      # May be modified by transitive dependency searches.
      set(${PKG}_FOUND TRUE)
      if (CETMODULES_TRANSITIVE_DEPS_PROJECT_${PKG})
        if (_cet_fp_QUIET)
          set(_cet_fp_QUIET QUIET)
        endif()
        if (_cet_fp_REQUIRED)
          set(_cet_fp_REQUIRED REQUIRED)
        endif()
        # Save the current value of CMAKE_FIND_PACKAGE_NAME.
        set(_fp_CMAKE_FIND_PACKAGE_NAME ${CMAKE_FIND_PACKAGE_NAME})
        set(CMAKE_FIND_PACKAGE_NAME ${PKG})
        if (NOT _fp_TRANSITIVE_DEPS_PROJECT_${PKG})
          string(REPLACE "find_dependency" "_cet_find_dependency"
            _fp_TRANSITIVE_DEPS_PROJECT_${PKG}
            "${CETMODULES_TRANSITIVE_DEPS_PROJECT_${PKG}}")
        endif()
        foreach (_cet_dep IN LISTS _fp_TRANSITIVE_DEPS_PROJECT_${PKG})
          cmake_language(EVAL CODE "${_fp_TRANSITIVE_DEPS_PROJECT_${PKG}}")
          if (NOT ${PKG}_FOUND)
            break()
          endif()
        endforeach()
        set(CMAKE_FIND_PACKAGE_NAME ${_fp_CMAKE_FIND_PACKAGE_NAME})
        unset(_fp_TRANSITIVE_DEPS_PROJECT_${PKG})
      endif()
      if (CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${PKG})
        list(TRANSFORM CETMODULES_CMAKE_MODULES_DIRECTORIES_PROJECT_${PKG}
          PREPEND "${${PKG}_SOURCE_DIR}/" REGEX "^[^/]+" OUTPUT_VARIABLE _fp_module_path)
        list(PREPEND CMAKE_MODULE_PATH "${_fp_module_path}")
        unset(_fp_module_path)
      endif()
    endif()
    set(${_fp_PKG_UC}_FOUND ${PKG}_FOUND)
    unset(_fp_PKG_UC)
  else()
    _cet_check_find_package_needed(${PKG} _cet_find_package_needed)
    if (_cet_find_package_needed)
      _find_package(${ARGV})
      if (COMMAND _cet_${PKG}_post_find_package)
        # Package-specific fixup if necessary.
        cmake_language(CALL _cet_${PKG}_post_find_package)
      endif()
    endif()
    unset(_cet_find_package_needed)
  endif()
  cmake_policy(POP)
endmacro()

macro(_cet_find_dependency dep)
  get_property(_cet_fd_alreadyTransitive GLOBAL PROPERTY
    _CMAKE_${dep}_TRANSITIVE_DEPENDENCY)
  find_package(${dep} ${ARGN} ${_cet_fp_QUIET} ${_cet_fp_REQUIRED})
  if (NOT DEFINED _cet_fd_alreadyTransitive OR _cet_fd_alreadyTransitive)
    set_property(GLOBAL PROPERTY _CMAKE_${dep}_TRANSITIVE_DEPENDENCY TRUE)
  endif()
  message(NOTIFY
    "${CMAKE_FIND_PACKAGE_NAME} could not be found because dependency ${dep} could not be found.")
  set(${CMAKE_FIND_PACKAGE_NAME}_FOUND FALSE)
endmacro()

function(_cet_check_find_package_needed PKG RESULT_VAR)
  set(${RESULT_VAR} TRUE PARENT_SCOPE)
  if (NOT ${PKG}_FOUND)
    return()
  endif()
  foreach (component IN LISTS _cet_fp_COMPONENTS _cet_fp_OPTIONAL_COMPONENTS)
    if (NOT ${PKG}_${component}_FOUND)
      return()
    endif()
  endforeach()
  set(${RESULT_VAR} FALSE PARENT_SCOPE)
endfunction()

macro(_cet_ROOT_post_find_package)
  # ROOT doesn't set ROOT_<component>_FOUND according to convention.
  foreach (component IN LISTS _cet_fp_COMPONENTS _cet_fp_OPTIONAL_COMPONENTS)
    if (ROOT_${component}_LIBRARY AND TARGET ROOT::${component})
      set(ROOT_${component}_FOUND TRUE)
    endif()
  endforeach()
endmacro()

cmake_policy(POP)
