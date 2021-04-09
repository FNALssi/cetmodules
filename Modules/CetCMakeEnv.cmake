#[================================================================[.rst:
CetCMakeEnv
===========

This module defines the principal boostrap function
:cmake:command:`cet_cmake_env` defining the cetmodules build environment for
the current project.
#]================================================================]

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.19...3.20 FATAL_ERROR)

# Override find package to deal with IN_TREE projects and reduce repeat
# intiializations.
include(private/CetOverrideFindPackage)

# Watch for changes to CMAKE_MODULE_PATH that could break
# forward/backward compatibility.
include(CetCMPCleaner)

include(CetRegexEscape)

##################
# OPTIONS
##################

# Are we making / using UPS?
option(WANT_UPS
  "Activate the generation of UPS table and version files and Unified \
UPS-compliant installation tarballs." OFF)
mark_as_advanced(WANT_UPS)

# What kind of things can we build?
option(BUILD_SHARED_LIBS "Build shared libraries (all projects)." ON)
option(BUILD_STATIC_LIBS "Build static libraries (all projects)." OFF)
option(BUILD_DOCS "Build documentation (all_projects)." ON)

# RPATH management.
option(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
mark_as_advanced(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)

# Module libraries for plugins:
if (NOT (DEFINED CACHE{CETMODULES_MODULE_PLUGINS} OR
      CMAKE_SYSTEM_NAME MATCHES "Darwin"))
    set(CETMODULES_MODULE_PLUGINS TRUE)
endif()
##################

##################
# Configure installation subdirectories.
##################

# Default subdirectory for libraries.
if (NOT CMAKE_INSTALL_LIBDIR)
  set(CMAKE_INSTALL_LIBDIR lib) # Don't use lib64 for installation dir.
endif()

# See https://cmake.org/cmake/help/latest/module/GNUInstallDirs.html.
include(GNUInstallDirs)
##################

#[================================================================[.rst:
#]================================================================]
define_property(TARGET PROPERTY CET_EXEC_LOCATION
  BRIEF_DOCS "Saved location of the executable represented by a target"
  FULL_DOCS "Saved location of the executable represented by a target")

#[================================================================[.rst:
.. cmake:command:: cet_cmake_env

  Set up the cetmodules build environment for the current project.

  **Synopsis:**
    .. code-block:: cmake

       cet_cmake_env([NO_INSTALL_PKGMETA])

  **Options:**
    ``NO_INSTALL_PKGMETA``

       Under normal circumstances, :cmake:command:`!cet_cmake_env` will
       call :cmake:command:`install_pkgmeta` to automatically find
       ``LICENSE`` and ``README`` files and install them. Specify
       ``NO_INSTALL_PKGMETA`` if you wish to call
       :cmake:command:`install_pkgmeta` yourself (or not at all).

  .. note::

     Prior to calling :cmake:command:`cet_cmake_env`:

     * The current project must have been initialized via
       :cmake:command:`project() <cmake:command:project>`

     * Any initial or override values for
       :cmake:manual:`cetmodules-project-variables.7` should be set.

  **Variables controlling behavior**
    * :cmake:variable:`WANT_UPS`
    * :cmake:variable:`BUILD_SHARED_LIBS <cmake:variable:BUILD_SHARED_LIBS>`
    * :cmake:variable:`BUILD_STATIC_LIBS`
    * :cmake:variable:`CMAKE_INSTALL_RPATH_USE_LINK_PATH <cmake:variable:CMAKE_INSTALL_RPATH_USE_LINK_PATH>`
#]================================================================]
macro(cet_cmake_env)
  # project() must have been called first.
  if (NOT CMAKE_PROJECT_NAME)
    message(FATAL_ERROR
      "CMake project() command must have been invoked prior to cet_cmake_env()."
      "\nIt must be invoked from the project's top level CMakeLists.txt, not in an included .cmake file.")
  endif()

  set(CETMODULES_CURRENT_PROJECT_NAME ${PROJECT_NAME})

  # Required to ensure correct installation location with
  # cetbuildtools-compatible installations.
  cmake_policy(SET CMP0082 NEW)

  # If this project is expecting to use cetbuildtools.
  _cetbuildtools_compatibility_early()

  # We need to know this, one way or the other.
  if (NOT PROJECT_VERSION)
    message(FATAL_ERROR "unable to ascertain CMake Project Version: add VERSION XX.YY.ZZ to project() call")
  endif()
  foreach (_cce_v IN ITEMS
      BINARY_DIR DESCRIPTION HOMEPAGE_URL NAME SOURCE_DIR
      VERSION VERSION_MAJOR VERSION_MINOR VERSION_PATCH VERSION_TWEAK
    )
    set(CETMODULES_CURRENT_PROJECT_${_cce_v} ${PROJECT_${_cce_v}})
  endforeach()
  unset(_cce_v)

  cmake_parse_arguments(_CCE "NO_INSTALL_PKGMETA" "" "" "${ARGV}")

  if (_CCE_UNPARSED_ARGUMENTS)
    warn_deprecated("cet_cmake_env(${ARGV})"
      " - remove unneeded legacy arguments ${_CCE_UNPARSED_ARGUMENTS}")
  endif()

  # Remove unwanted information from any previous run.
  _clean_internal_cache_entries()

  # Disable package registry use as confusing and not best practice.
  set(CMAKE_EXPORT_PACKAGE_REGISTRY FALSE)
  set(CMAKE_EXPORT_NO_PACKAGE_REGISTRY TRUE)
  set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
  set(CMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY TRUE)

  # Ask CMake to exit on error at install time if it is asked to install
  # files in an absolute location.
  set(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION TRUE)

  ##################
  # Project variables - see ProjectVariable.cmake. See especially the
  # explanation of initialization and default semantics.
  ##################
  include(ProjectVariable)

  # Enable our config file to detect whether we're being built and
  # imported in the same run. Note that this variable is *not* exported
  # to external dependents.
  project_variable(IN_TREE TRUE TYPE BOOL DOCSTRING
    "Signifies whether ${PROJECT_NAME} is currently being built")

  # Defined first, as PATH_FRAGMENT and FILEPATH_FRAGMENT project
  # variables take this into account.
  project_variable(EXEC_PREFIX TYPE STRING)

  # Other generally-useful project variables. More may be defined where
  # they are relevant.
  project_variable(OLD_STYLE_CONFIG_VARS FALSE TYPE BOOL
    DOCSTRING "Tell cetmodules config files for dependencies to define \
old-style variables for library targets\
")
  project_variable(NAMESPACE "${PROJECT_NAME}"
    TYPE STRING CONFIG OMIT_IF_NULL
    DOCSTRING "Top-level prefix for targets and aliases when imported")
  project_variable(INCLUDE_DIR "${CMAKE_INSTALL_INCLUDEDIR}" CONFIG
    OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
    DOCSTRING "Directory below prefix to install headers")
  project_variable(LIBRARY_DIR "${CMAKE_INSTALL_LIBDIR}" CONFIG
    OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
    DOCSTRING "Directory below prefix to install libraries")
  project_variable(BIN_DIR "${CMAKE_INSTALL_BINDIR}" CONFIG
    OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
    DOCSTRING "Directory below prefix to install executables")
  project_variable(SCRIPTS_DIR ${${PROJECT_NAME}_BIN_DIR}
    NO_WARN_REDUNDANT
    BACKUP_DEFAULT scripts
    OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
    DOCSTRING "Directory below prefix to install scripts")
  project_variable(TEST_DIR "test"
    NO_WARN_REDUNDANT
    OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
    DOCSTRING "Directory below prefix to install tests")
  project_variable(DATA_ROOT_DIR ${CMAKE_INSTALL_DATAROOTDIR}
    NO_WARN_REDUNDANT
    OMIT_IF_EMPTY OMIT_IF_MISSING OMIT_IF_NULL
    DOCSTRING "Architecture-independent data directory")

  # If we're dealing with UPS.
  if (WANT_UPS)
    # Incorporate configuration information from product_deps.
    include(Ups)
    _ups_init()
    if (CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME OR
        NOT DEFINED CACHE{CETMODULES_CMAKE_INSTALL_PREFIX_ORIG})
      set(CETMODULES_CMAKE_INSTALL_PREFIX_ORIG "${CMAKE_INSTALL_PREFIX}"
        CACHE INTERNAL "Original value of CMAKE_INSTALL_PREFIX")
    else()
      set(CMAKE_INSTALL_PREFIX "${CETMODULES_CMAKE_INSTALL_PREFIX_ORIG}")
    endif()
    # Tweak the value of CMAKE_INSTALL_PREFIX used by the project's
    # cmake_install.cmake files per UPS conventions.
    install(CODE "\
# Tweak the value of CMAKE_INSTALL_PREFIX used by the project's
  # cmake_install.cmake files per UPS conventions.
  string(APPEND CMAKE_INSTALL_PREFIX \"/${${PROJECT_NAME}_UPS_PRODUCT_SUBDIR}\")\
")
    # Install a delayed installation of a delayed function call to fix
    # legacy installations.
    cmake_language(DEFER DIRECTORY "${PROJECT_SOURCE_DIR}" CALL
      cmake_language DEFER DIRECTORY "${PROJECT_SOURCE_DIR}" CALL _restore_install_prefix)
  else()
    # Define a fallback macro in case of layer 8 issues.
    macro(process_ups_files)
      message(FATAL_ERROR
        "Set the CMake variable WANT_UPS prior to including CetCMakeEnv.cmake to activate UPS table file and tarball generation.")
    endmacro()
  endif()

  # Useful includes.
  include(CTest)
  include(CetCMakeConfig)
  include(CetCMakeUtils)
  include(CetMakeLibrary)
  include(CetMake)
  include(Compatibility)
  include(FindUpsBoost)
  include(FindUpsGeant4)
  include(FindUpsRoot)
  include(InstallFW)
  include(InstallFhicl)
  include(InstallGdml)
  include(InstallHeaders)
  include(InstallLicense)
  include(InstallPerllib)
  include(InstallScripts)
  include(InstallSource)
  include(InstallWP)
  include(SetCompilerFlags)

  _cetbuildtools_compatibility_late()

  ##################
  # Default locations for libraries and executables.
  ##################

  # Override on a per-target, per config or per-scope basis if necessary
  # (should be rare).
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY
    ${PROJECT_BINARY_DIR}/${${PROJECT_NAME}_LIBRARY_DIR})
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY
    ${PROJECT_BINARY_DIR}/${${PROJECT_NAME}_LIBRARY_DIR})
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY
    ${PROJECT_BINARY_DIR}/${${PROJECT_NAME}_BIN_DIR})

  ##################
  # Automatic installation of LICENSE, README, etc. unless disabled by
  # NO_INSTALL_PKGMETA.
  if (NOT _CCE_NO_INSTALL_PKGMETA)
    install_pkgmeta()
  endif()

  ##################
  # Avoid warnings about some variables that are likely to have been set
  # on the command line but that may not be used.
  _use_maybe_unused()
endmacro(cet_cmake_env)

function(_clean_internal_cache_entries)
  get_property(cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  cet_regex_escape("${PROJECT_NAME}" e_proj)
  list(FILTER cache_vars INCLUDE
    REGEX "^_?CETMODULES(_[^_]+)*_PROJECT_${e_proj}$")
  foreach (entry IN LISTS cache_vars)
    get_property(type CACHE "${entry}" PROPERTY TYPE)
    if (type STREQUAL INTERNAL)
      unset("${entry}" CACHE)
    endif()
  endforeach()
endfunction()

macro(_cetbuildtools_compatibility_early)
  set(product "${${PROJECT_NAME}_UPS_PRODUCT_NAME}")
  if (UPS_${product}_CMAKE_PROJECT_VERSION AND
      PROJECT_VERSION AND
      NOT UPS_${product}_CMAKE_PROJECT_VERSION STREQUAL PROJECT_VERSION)
    if (COMMAND mrb_check_subdir_order) # Using mrb.
      set(_cce_since "mrbsetenv was run")
      set(_cce_action "re-run mrbsetenv")
    else()
      set(_cce_since "setup_for_development was sourced")
      set(_cce_action "re-source setup_for_development")
    endif()
    message(FATAL_ERROR "Version of ${PROJECT_NAME} in CMakeLists.txt has changed since ${_cce_since} - ${_cce_action}
  -> \"${UPS_${product}_CMAKE_PROJECT_VERSION}\" (from setup) != \"${PROJECT_VERSION}\" (in CMakeLists.txt)")
  endif()
  set(version "${${PROJECT_NAME}_UPS_PRODUCT_VERSION}")
  if ("cetbuildtools"
      IN_LIST ${PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES AND
      NOT PROJECT_VERSION)
    set(PROJECT_VERSION ${UPS_${product}_CMAKE_PROJECT_VERSION})
    parse_version_string("${PROJECT_VERSION}" PROJECT_VERSION_MAJOR PROJECT_VERSION_MINOR PROJECT_VERSION_PATCH PROJECT_VERSION_TWEAK)
    if (PROJECT_NAME STREQUAL CMAKE_PROJECT_NAME)
      foreach (_cce_v IN ITEMS "" _MAJOR _MINOR _PATCH _TWEAK)
        set(CMAKE_PROJECT_VERSION${_cce_v} ${PROJECT_VERSION${_cce_v}})
      endforeach()
      unset(_cce_v)
    endif()
  endif()
  set(UPSFLAVOR "${${PROJECT_NAME}_UPS_PRODUCT_FLAVOR}")
  set(flavorqual "${${PROJECT_NAME}_EXEC_PREFIX}")
  set(full_qualifier "${${PROJECT_NAME}_UPS_QUALIFIER_STRING}")
  string(REPLACE ":" ";" qualifier "${full_qualifier}")
  list(REMOVE_ITEM qualifier debug opt prof)
  string(REPLACE ";" ":" qualifier "${qualifier}")
  set(${product}_full_qualifier "${full_qualifier}")
  set(flavorqual_dir "${product}/${version}/${flavorqual}")
endmacro()

function(_cetbuildtools_compatibility_late)
  if (NOT "cetbuildtools" IN_LIST ${PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES)
    return()
  endif()
  get_property(cetb_translate_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  list(FILTER cetb_translate_vars INCLUDE REGEX "^CETB_COMPAT_")
  list(TRANSFORM cetb_translate_vars REPLACE "^CETB_COMPAT_(.*)$" "\\1"
    OUTPUT_VARIABLE cetb_var_stems)
  foreach (var_stem translate_var IN ZIP_LISTS
      cetb_var_stems cetb_translate_vars)
    if (${translate_var} IN_LIST CETMODULES_VARS_PROJECT_${PROJECT_NAME})
      set(val "${${PROJECT_NAME}_${${translate_var}}}")
    else() # Too early: need placeholder.
      set(val "\${${PROJECT_NAME}_${${translate_var}}}")
    endif()
    set(${product}_${var_stem} "${val}" CACHE INTERNAL
      "Compatibility variable for packages expecting cetbuildtools")
  endforeach()
endfunction()

function(_use_maybe_unused)
  get_property(cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  cet_regex_escape("${PROJECT_NAME}" e_proj)
  list(FILTER cache_vars INCLUDE REGEX "^${e_proj}.*_INIT")
  foreach (var IN LISTS cache_vars ITEMS CMAKE_WARN_DEPRECATED)
    if (${var})
    endif()
  endforeach()
endfunction()

function(_restore_install_prefix)
  message(VERBOSE "Executing delayed install(CODE...)")
  # With older CMakeLists.txt files, deal with low level install()
  # invocations with an extra "${project}/${version}"
  install(CODE "\
# Detect misplaced installs from older, cetbuildtools-using packages.
  if (IS_DIRECTORY \"\${CMAKE_INSTALL_PREFIX}/${product}/${version}\")
    message(VERBOSE \"tidying legacy installations: relocate ${product}/${version}/*\")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar c \"../../${product}_${version}-tmpinstall.tar\" .
                    WORKING_DIRECTORY \"\${CMAKE_INSTALL_PREFIX}/${product}/${version}\"
                    COMMAND_ERROR_IS_FATAL ANY)
    file(REMOVE_RECURSE \"\${CMAKE_INSTALL_PREFIX}/${product}/${version}\")
    execute_process(COMMAND ${CMAKE_COMMAND} -E tar xv \"${product}_${version}-tmpinstall.tar\"
                    WORKING_DIRECTORY \"\${CMAKE_INSTALL_PREFIX}\"
                    OUTPUT_VARIABLE _cet_install_${product}_legacy
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    COMMAND_ERROR_IS_FATAL ANY)
    message(VERBOSE \"\${_cet_install_${product}_legacy}\")
    unset(_cet_install_${product}_legacy)
    file(REMOVE \"\${CMAKE_INSTALL_PREFIX}/${product}_${version}-tmpinstall.tar\")
  endif()

  # We need to reset CMAKE_INSTALL_PREFIX to its original value at this
  # time.
  get_filename_component(CMAKE_INSTALL_PREFIX \"\${CMAKE_INSTALL_PREFIX}\" DIRECTORY)
  get_filename_component(CMAKE_INSTALL_PREFIX \"\${CMAKE_INSTALL_PREFIX}\" DIRECTORY)\
")
  cet_regex_escape("/${product}/${version}" e_pv 1)
  # Fix the install manifest at the top level.
  cmake_language(EVAL CODE "\
cmake_language(DEFER DIRECTORY \"${CMAKE_SOURCE_DIR}\" CALL
  install CODE \"\
list(TRANSFORM CMAKE_INSTALL_MANIFEST_FILES REPLACE \\\"${e_pv}${e_pv}\\\" \\\"/${product}/${version}\\\")\
\")\
")
endfunction()

cmake_policy(POP)
