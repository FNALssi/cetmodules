#[================================================================[.rst:
CetCMakeEnv
===========

This module defines the principal bootstrap function
:cmake:command:`cet_cmake_env` defining the cetmodules build environment for
the current project.
#]================================================================]

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.19...3.20 FATAL_ERROR)

# Override find package to deal with IN_TREE projects and reduce repeat
# initializations.
include(private/CetOverrideFindPackage)

# Handle setting of versions with a non-numeric component:
include(private/CetHandleExtendedVersion)

# Escape characters for literal use in regular expressions.
include(CetRegexEscape)

# Project variables.
include(ProjectVariable)

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
       :cmake:command:`project() <cmake-ref-current:command:project>`

     * Any initial or override values for
       :cmake:manual:`project variables <cetmodules-project-variables(7)>` should be set.

  **Variables controlling behavior**
    * :cmake:variable:`WANT_UPS`
    * :cmake:variable:`BUILD_SHARED_LIBS <cmake-ref-current:variable:BUILD_SHARED_LIBS>`
    * :cmake:variable:`BUILD_STATIC_LIBS`
    * :cmake:variable:`CMAKE_INSTALL_RPATH_USE_LINK_PATH <cmake-ref-current:variable:CMAKE_INSTALL_RPATH_USE_LINK_PATH>`
#]================================================================]
macro(cet_cmake_env)
  # project() must have been called first.
  if (NOT CMAKE_PROJECT_NAME)
    message(FATAL_ERROR
      "CMake project() command must have been invoked prior to cet_cmake_env()."
      "\nIt must be invoked from the project's top level CMakeLists.txt, not in an included .cmake file.")
  endif()

  cmake_parse_arguments(_CCE "NO_INSTALL_PKGMETA" "" "" "${ARGV}")

  set(CETMODULES_CURRENT_PROJECT_NAME ${PROJECT_NAME})
  get_filename_component(CETMODULES_CURRENT_PROJECT_LIST_FILE "${CMAKE_CURRENT_LIST_FILE}" REALPATH)
  string(SHA256 CETMODULES_CURRENT_PROJECT_VARIABLE_PREFIX "${CETMODULES_CURRENT_PROJECT_LIST_FILE}")
  set(CET_PV_PREFIX CACHE STRING "List of initial project variable project identifier prefixes")
  mark_as_advanced(CET_PV_PREFIX)
  if (NOT CET_PV_PREFIX STREQUAL "")
    foreach (_cce_pvp_candidate IN LISTS CET_PV_PREFIX)
      if (CETMODULES_CURRENT_PROJECT_VARIABLE_PREFIX MATCHES "^${_cce_pvp_candidate}")
        set(CETMODULES_CURRENT_PROJECT_VARIABLE_PREFIX "CET_PV_${_cce_pvp_candidate}")
        break()
      endif()
    endforeach()
  endif()

  # Required to ensure correct installation location with
  # cetbuildtools-compatible installations.
  cmake_policy(SET CMP0082 NEW)

  # Remove unwanted information from any previous run.
  _clean_internal_cache_entries()

  ##################
  # Project variables - see ProjectVariable.cmake. See especially the
  # explanation of initialization and default semantics.
  ##################

  # Enable our config file to detect whether we're being built and
  # imported in the same run. Note that this variable is *not* exported
  # to external dependents.
  project_variable(IN_TREE TRUE TYPE BOOL DOCSTRING
    "Signifies whether ${CETMODULES_CURRENT_PROJECT_NAME} is currently being built")

  # Defined first, as PATH_FRAGMENT and FILEPATH_FRAGMENT project
  # variables take this into account.
  project_variable(EXEC_PREFIX TYPE STRING)

  project_variable(OLD_STYLE_CONFIG_VARS FALSE TYPE BOOL
    DOCSTRING
    "Define configuration variables and accommodate (anti-)patterns \
used by CMake code ported from cetbuildtools")

  # If this project is expecting to use cetbuildtools.
  _cetbuildtools_compatibility_early()

  ####################################
  # Enable projects to specify an extended version with a non-numeric
  # trailing component (e.g. -rc1, or -alpha, or -p03), and deal with it
  # in the right places.
  project_variable(CMAKE_PROJECT_VERSION_STRING ${PROJECT_VERSION}
    TYPE STRING DOCSTRING
    "Extended project version, with optional non-numeric trailing \
component(M[.m[.p[.t]]][-X])\
")

  # Ensure we have version settings.
  _cet_handle_extended_version()

  if ("${PROJECT_VERSION_EXTRA}" STREQUAL "")
    set(_cce_ext_v_def FALSE)
  else()
    set(_cce_ext_v_def TRUE)
  endif()

  project_variable(EXTENDED_VERSION_SEMANTICS
    ${_cce_ext_v_def} TYPE BOOL DOCSTRING
    "Use extended version semantics permitting a non-numeric trailing \
component, with sensible comparison semantics for alpha, rc and other \
recognized version formats\
")

  if (_cce_ext_v_def AND
      NOT ${CETMODULES_CURRENT_PROJECT_NAME}_EXTENDED_VERSION_SEMANTICS)
    message(SEND_ERROR "Extended semantics for CMAKE_PROJECT_VERSION (${PROJECT_VERSION}) for project ${CETMODULES_CURRENT_PROJECT_NAME} prohibited by ${CETMODULES_CURRENT_PROJECT_NAME}_EXTENDED_VERSION_SEMANTICS")
  endif()
  unset(_cce_ext_v_def)
  ####################################

  # Avoid confusion with nested subprojects.
  foreach (_cce_v IN ITEMS
      BINARY_DIR DESCRIPTION HOMEPAGE_URL SOURCE_DIR
      VERSION VERSION_MAJOR VERSION_MINOR VERSION_PATCH VERSION_TWEAK
      VERSION_EXTRA VERSION_EXTRA_TYPE VERSION_EXTRA_TEXT VERSION_EXTRA_NUM
      )
    set(CETMODULES_CURRENT_PROJECT_${_cce_v} ${PROJECT_${_cce_v}})
  endforeach()
  unset(_cce_v)

  # Check for obsolete arguments.
  if (_CCE_UNPARSED_ARGUMENTS)
    warn_deprecated("cet_cmake_env(${ARGV})"
      " - remove unneeded legacy arguments ${_CCE_UNPARSED_ARGUMENTS}")
  endif()

  # Disable package registry use as confusing and not best practice.
  set(CMAKE_EXPORT_PACKAGE_REGISTRY FALSE)
  set(CMAKE_EXPORT_NO_PACKAGE_REGISTRY TRUE)
  set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
  set(CMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY TRUE)

  # Ask CMake to exit on error at install time if it is asked to install
  # files in an absolute location.
  set(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION TRUE)

  project_variable(NAMESPACE "${CETMODULES_CURRENT_PROJECT_NAME}"
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
  project_variable(SCRIPTS_DIR ${${CETMODULES_CURRENT_PROJECT_NAME}_BIN_DIR}
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
    include(compat/Ups)
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
  string(APPEND CMAKE_INSTALL_PREFIX \"/${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_SUBDIR}\")\
")
    if (NOT "${product}" STREQUAL "")
      # Install a delayed installation of a delayed function call to fix
      # legacy installations.
      cmake_language(DEFER DIRECTORY "${PROJECT_SOURCE_DIR}" CALL
        cmake_language DEFER DIRECTORY "${PROJECT_SOURCE_DIR}" CALL _restore_install_prefix)
    endif()
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
  include(CetMake)
  include(CetMakeLibrary)
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
  include(compat/CetFindPackage)
  include(compat/CetHaveQual)
  include(compat/CetParseArgs)
  include(compat/CheckProdVersion)
  include(compat/CheckUpsVersion)
  include(compat/Compatibility)
  include(compat/FindUpsBoost)
  include(compat/FindUpsGeant4)
  include(compat/FindUpsRoot)
  include(compat/ParseUpsVersion)

  _cetbuildtools_compatibility_late()

  ##################
  # Default locations for libraries and executables.
  ##################

  # Override on a per-target, per config or per-scope basis if necessary
  # (should be rare).
  set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY
    ${PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY_DIR})
  set(CMAKE_LIBRARY_OUTPUT_DIRECTORY
    ${PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY_DIR})
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY
    ${PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_BIN_DIR})

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

  ##################
  # Initiate watch for changes to CMAKE_MODULE_PATH that could break
  # forward/backward compatibility.
  include(compat/art/CetCMPCleaner)
endmacro(cet_cmake_env)

function(_clean_internal_cache_entries)
  get_property(cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  cet_regex_escape("${CETMODULES_CURRENT_PROJECT_NAME}" e_proj)
  list(FILTER cache_vars INCLUDE
    REGEX "^_?CETMODULES(_[^_]+)*_PROJECT_${e_proj}$")
  foreach (entry IN LISTS cache_vars)
    get_property(type CACHE "${entry}" PROPERTY TYPE)
    if (type STREQUAL "INTERNAL")
      unset("${entry}" CACHE)
    endif()
  endforeach()
endfunction()

macro(_cetbuildtools_compatibility_early)
  if (${CETMODULES_CURRENT_PROJECT_NAME}_OLD_STYLE_CONFIG_VARS OR
      "cetbuildtools" IN_LIST ${CETMODULES_CURRENT_PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES)
    if (COMMAND mrb_check_subdir_order) # Using mrb.
      set(_cce_action "re-run mrbsetenv")
    else()
      set(_cce_action "re-source setup_for_development")
    endif()
    if (${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME)
      set(product "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME}")
    else()
      message(FATAL_ERROR "\
Using cetbuildtools compatibility but cannot find UPS product name from \
${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_NAME - ${_cce_action}\
")
    endif()
    set(version "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_VERSION}")
    set(UPSFLAVOR "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_FLAVOR}")
    set(flavorqual "${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}")
    set(full_qualifier "${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_QUALIFIER_STRING}")
    string(REPLACE ":" ";" qualifier "${full_qualifier}")
    list(REMOVE_ITEM qualifier debug opt prof)
    string(REPLACE ";" ":" qualifier "${qualifier}")
    set(${product}_full_qualifier "${full_qualifier}")
    set(flavorqual_dir "${product}/${version}/${flavorqual}")
    unset(_cce_action)
  endif()
endmacro()

function(_cetbuildtools_compatibility_late)
  if (NOT "cetbuildtools" IN_LIST ${CETMODULES_CURRENT_PROJECT_NAME}_UPS_BUILD_ONLY_DEPENDENCIES)
    return()
  endif()
  get_property(cetb_translate_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  list(FILTER cetb_translate_vars INCLUDE REGEX "^CETB_COMPAT_")
  if (cetb_translate_vars)
    mark_as_advanced(${cetb_translate_vars})
  endif()
  list(TRANSFORM cetb_translate_vars REPLACE "^CETB_COMPAT_(.*)$" "\\1"
    OUTPUT_VARIABLE cetb_var_stems)
  foreach (var_stem translate_var IN ZIP_LISTS
      cetb_var_stems cetb_translate_vars)
    if (${translate_var} IN_LIST CETMODULES_VARS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME})
      set(val "${${CETMODULES_CURRENT_PROJECT_NAME}_${${translate_var}}}")
    else() # Too early: need placeholder.
      set(val "\${${CETMODULES_CURRENT_PROJECT_NAME}_${${translate_var}}}")
    endif()
    set(${product}_${var_stem} "${val}" CACHE INTERNAL
      "Compatibility variable for packages expecting cetbuildtools")
  endforeach()
endfunction()

function(_use_maybe_unused)
  get_property(cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  list(FILTER cache_vars INCLUDE REGEX "(^CET_PV_|^${CMAKE_CURRENT_PROJECT_VARIABLE_PREFIX}_|_INIT$)")
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
