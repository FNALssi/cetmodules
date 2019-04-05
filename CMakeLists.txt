# ======================================================================
#  cetmodules
# ======================================================================

# Required to keep CMake happy.
cmake_minimum_required(VERSION ${CMAKE_VERSION} FATAL_ERROR)
# Actual version requirement.
cmake_policy(VERSION 3.3)

# Project information.
project(cetmodules VERSION 1.00.00 LANGUAGES NONE)

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/Modules)

include(CetCMakeEnv)
cet_cmake_env(NO_FLAVOR PAD_MINOR ON)

add_subdirectory(config)
add_subdirectory(Modules)
add_subdirectory(bin)
add_subdirectory(src)

include(CetCMakeConfig)
cet_cmake_config(NO_FLAVOR)
if (WANT_UPS)
  add_subdirectory(ups)
endif()
