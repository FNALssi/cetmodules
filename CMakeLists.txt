########################################################################
# cetmodules
#
#   Scripts and CMake modules to aid in the building and use of
#   interdependent scientific software.
#
# FEATURES:
#
# * Compatibility with cetbuildtools and UPS environments with only
#   minor changes.
#
# * Facilities for ROOT dictionary / C++ module generation.
#
# * Facilities for generation of art suite modules, module skeleton
#   generators, services, and tools.
#
# * Assisted production of libraries, executables and other targets
#   using modern CMake idioms
#
# * Assisted production of full-featured CMake config files with target
#   import / export and dependency management.
#
# * Easy installation and management of different types of data file
#   with relevance to HEP and beyond, including FHiCL, GDML, and source.
#
# * Awareness of multi-project builds.
#
########################################################################

# Required to keep CMake happy.
cmake_minimum_required(VERSION 3.18.2...3.21 FATAL_ERROR)

# Project information.
project(cetmodules VERSION 2.25.00 LANGUAGES NONE)

# Bootstrap finding our own modules.
list(PREPEND CMAKE_MODULE_PATH
  ${PROJECT_BINARY_DIR}/Modules
  ${PROJECT_SOURCE_DIR}/Modules
  ${PROJECT_SOURCE_DIR}/Modules/compat)

# Other configuration.
set(${PROJECT_NAME}_NOARCH TRUE)
set(${PROJECT_NAME}_FHICL_DIR "")
set(${PROJECT_NAME}_INCLUDE_DIR "")
set(${PROJECT_NAME}_LIBRARY_DIR "")

# Basic build environment.
include(CetCMakeEnv)
cet_cmake_env()

project_variable(MIN_CETBUILDTOOLS_VERSION 8.04.00 TYPE STRING CONFIG
  DOCSTRING "Minimum version of cetbuildtools compatible with this version---${cetmodules_VERSION}---of cetmodules")

# Make sure downstream packages can find our modules.
cet_cmake_module_directories(NO_LOCAL Modules Modules/compat)

####################################
# Build components.
add_subdirectory(config)
add_subdirectory(Modules)
add_subdirectory(libexec)
add_subdirectory(tools)
add_subdirectory(bin)
add_subdirectory(src)
add_subdirectory(ups-templates)
include(CTest)
if (BUILD_TESTING)
  add_subdirectory(test)
endif()
add_subdirectory(doc)
####################################

####################################
# Generate CMake (and UPS, if appropriate) configuration files and
# packaging.
cet_cmake_config(EXTRA_TARGET_VARS CET_EXEC_TEST
  CONFIG_PRE_INIT
  config/${PROJECT_NAME}-cmake-version-check.cmake
  config/${PROJECT_NAME}-override-toolchain.cmake
  config/${PROJECT_NAME}-CMP0096.cmake
)
