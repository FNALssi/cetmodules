########################################################################
# CetCMakeEnv
#
#   Set up a characteristic cetmodules build environment for the current
#   project.
#
####################################
# FUNCTIONS / MACROS
##################
#
#   cet_cmake_env([NO_INSTALL_PKGMETA])
#
#     Set up the cetmodules build environment.
#
####################################
# CONFIGURATION
##################
#
##################
# Top-level configuration options (-D<opt>:BOOL=<ON|OFF>).
##################
#
#   BUILD_SHARED_LIBS (ON)
#   BUILD_STATIC_LIBS (OFF)
#
#     Specify which types of library should be built - see
#     https://cmake.org/cmake/help/latest/variable/BUILD_SHARED_LIBS.html.
#
#   CMAKE_INSTALL_RPATH_USE_LINK_PATH (ON)
#
#     Specify CMake's behavior with respect to RPATH - see
#     https://cmake.org/cmake/help/latest/variable/CMAKE_INSTALL_RPATH_USE_LINK_PATH.html.
#
#   WANT_UPS (OFF)
#
#     Activate the generation of UPS table and version files and Unified
#     UPS-compliant installation tarballs. If you don't know what this
#     means you don't need it. For details of command-line CMake
#     variables (-D...) and optional arguments to cet_cmake_env() to
#     modify behavior of the UPS handling system, please see the
#     documentation in Ups.cmake.
#
##################
# "Project" variables - see ProjectVariable.cmake.
##################
#
#  * Set for the current project on the command line with:
#
#      -D<cmake-project-name>_<var>_INIT=<val>
#
#    or in CMakeLists.txt with:
#
#      set(<cmake-project-name>_<var> <val>).
#
#  * Set for the current and all nested projects with:
#
#      set(<var> <val>).
#
##################
# cet_cmake_env([NO_INSTALL_PKGMETA])
##################
#
# Set up the cetmodules build environment.
#
##################
#
#
#   NO_INSTALL_PKGMETA
#
#     Under normal circumstances, cet_cmake_env() will automatically
#     find LICENSE and README files and install them. Specify
#     NO_INSTALL_PKGMETA if you wish to call install_pkgmeta()
#     yourself (or not at all).
#
########################################################################

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetRegexEscape)

##################
# OPTIONS
##################

# Are we making / using UPS?
option(WANT_UPS
  "Activate the generation of UPS table and version files and Unified \
UPS-compliant installation tarballs." OFF)
mark_as_advanced(WANT_UPS)

# What kind of libraries do we build?
option(BUILD_SHARED_LIBS "Build shared libraries for this project." ON)
option(BUILD_STATIC_LIBS "Build static libraries for this project." OFF)

# RPATH management.
option(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
mark_as_advanced(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)
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

macro(cet_cmake_env)
  # project() must have been called first.
  if (NOT CMAKE_PROJECT_NAME)
    message(FATAL_ERROR
      "CMake project() command must have been invoked prior to cet_cmake_env()."
      "\nIt must be invoked from the project's top level CMakeLists.txt, not in an included .cmake file.")
  endif()

  cmake_parse_arguments(_CCE "NO_INSTALL_PKGMETA" "" "" "${ARGV}")

  # Remove unwanted information from any previous run.
  _clean_internal_cache_entries()

  # Disable package registry use as confusing and not best practice.
  set(CMAKE_EXPORT_PACKAGE_REGISTRY FALSE)
  set(CMAKE_EXPORT_NO_PACKAGE_REGISTRY TRUE)
  set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
  set(CMAKE_FIND_PACKAGE_NO_SYSTEM_PACKAGE_REGISTRY TRUE)

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
  elseif (NOT WANT_UPS)
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

function(_use_maybe_unused)
  get_property(cache_vars DIRECTORY PROPERTY CACHE_VARIABLES)
  cet_regex_escape("${PROJECT_NAME}" e_proj)
  list(FILTER cache_vars INCLUDE REGEX "^${e_proj}.*_INIT")
  foreach (var IN LISTS cache_vars ITEMS CMAKE_WARN_DEPRECATED)
    if (${var})
    endif()
  endforeach()
endfunction()

cmake_policy(POP)
