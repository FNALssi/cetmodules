include_guard()

# Ensure that leading zeros are honored in project(VERSION ...) calls.
if (POLICY CMP0096)
  cmake_policy(SET CMP0096 NEW)
endif()
cmake_policy(PUSH)

cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

if (CET_BUILD_SYSTEM STREQUAL "cetbuildtools")
  list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/compat)
  find_package(cetbuildtools 8.00.00 REQUIRED)
else()
  list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})
  find_package(cetmodules 2.10.00 REQUIRED)
endif()
cmake_policy(POP)
