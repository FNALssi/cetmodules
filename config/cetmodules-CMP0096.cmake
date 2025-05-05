# Ensure that leading zeros are honored in project(VERSION ...) calls.
if(POLICY CMP0096)
  # https://cmake.org/cmake/help/latest/policy/CMP0096.html
  cmake_policy(SET CMP0096 NEW)
endif()
