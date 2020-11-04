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
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

# Project information.
project(cetmodules VERSION 2.00.02 LANGUAGES NONE)

# Find our own modules.
list(PREPEND CMAKE_MODULE_PATH ${PROJECT_SOURCE_DIR}/Modules
  ${PROJECT_SOURCE_DIR}/Modules/compat)

# No tests of cetmodules.
set(BUILD_TESTING OFF)

# Basic build environment.
include(CetCMakeEnv)
cet_cmake_env()

####################################
# Build components.
add_subdirectory(config)
add_subdirectory(Modules)
add_subdirectory(libexec)
add_subdirectory(tools)
add_subdirectory(bin)
add_subdirectory(src)
add_subdirectory(ups-templates)
####################################

# We need these to be absolute for internal use.
cet_internalize_pv(CONFIG_DIR LIBEXEC_DIR)

####################################
# Generate CMake (and UPS, if appropriate) configuration files and
# packaging.
cet_cmake_config(COMPATIBILITY SameMajorVersion
  CONFIG_PRE_INIT config/${PROJECT_NAME}-override-toolchain.cmake.in
  CONFIG_POST_VARS config/${PROJECT_NAME}-config-module-path.cmake.in)
