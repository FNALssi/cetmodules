if(CMAKE_VERSION VERSION_LESS @cetmodules_MIN_CMAKE_VERSION@)
  message(
    FATAL_ERROR
      "several features of cetmodules require CMake>=@cetmodules_MIN_CMAKE_VERSION@"
    )
endif()
