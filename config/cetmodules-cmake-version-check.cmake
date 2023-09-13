if (CMAKE_VERSION VERSION_LESS @CETMODULES_MIN_CMAKE_VERSION@)
  message(FATAL_ERROR "several features of cetmodules require CMake>=@CETMODULES_MIN_CMAKE_VERSION@")
endif()
