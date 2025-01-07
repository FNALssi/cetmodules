########################################################################
# cetmodules
#
#   Scripts and CMake modules to aid in the building and use of
#   interdependent scientific software.
#
# FEATURES:
#
# * Facilities for ROOT dictionary / C++ module generation.
#
# * Assisted production of libraries, executables and other targets
#   using modern CMake idioms
#
# * Assisted production of full-featured CMake config files with target
#   import / export and dependency management.
#
# * Easy installation and management of different types of data file
#   with relevance to HEP and beyond, including FHiCL, GDML, and source.
########################################################################

# This variable is required in the cmake_minimum_required() call below,
# and is also used as the initial value of the corresponding project
# variable MIN_CMAKE_VERSION defined below.
set(cetmodules_MIN_CMAKE_VERSION 3.22)

# Required to keep CMake happy.
cmake_minimum_required(VERSION ${cetmodules_MIN_CMAKE_VERSION}...3.31
  FATAL_ERROR)

####################################
# Project information.
project(cetmodules LANGUAGES NONE)

# Bootstrap finding our own modules.
list(PREPEND CMAKE_MODULE_PATH
  ${PROJECT_SOURCE_DIR}/Modules
  ${PROJECT_BINARY_DIR}/Modules)

# Version handling.
include(CetSetVersionFromFile)
cet_set_version_from_file(EXTENDED_VERSION_SEMANTICS)

####################################

include(CetCMakeEnv) # Basic build environment.
include(CetCMakeUtils) # For cet_cmake_module_directories().
include(CetCMakeConfig) # For cet_cmake_config().

# Our project-specific settings.
set(cetmodules_ADD_NOARCH_DIRS_INIT BIN_DIR LIBEXEC_DIR)
set(cetmodules_CONFIG_OUTPUT_ROOT_DIR_INIT share)

# Initialize the environment.
cet_cmake_env()

# cetmodules_MIN_CMAKE_VERSION is used in this project to generate
# etc/cmake_required_version.txt, and by cet_test() in this and other
# projects to generate CMakeLists.txt files required for COMPILE_ONLY
# tests (see Modules/CetTest.cmake).
project_variable(MIN_CMAKE_VERSION TYPE STRING CONFIG
  DOCSTRING "Minimum version of CMake compatible with this version---${cetmodules_VERSION}---of cetmodules")

# Make sure downstream packages can find our modules.
cet_cmake_module_directories(NO_LOCAL Modules Modules/compat)

####################################
# Build components.
add_subdirectory(config)
add_subdirectory(etc)
add_subdirectory(Modules)
add_subdirectory(libexec)
add_subdirectory(src)
include(CTest)
if (BUILD_TESTING)
  add_subdirectory(test)
endif()
if (BUILD_DOCS)
  add_subdirectory(doc)
endif()
####################################

####################################
# Generate CMake configuration files and packaging.
cet_cmake_config(CONFIG_PRE_INIT
  config/${PROJECT_NAME}-cmake-version-check.cmake
  config/${PROJECT_NAME}-override-toolchain.cmake
  config/${PROJECT_NAME}-CMP0096.cmake
  CONFIG_POST_VARS
  config/${PROJECT_NAME}-no-in-tree-source-modules.cmake
)
