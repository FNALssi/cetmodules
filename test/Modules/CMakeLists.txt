add_test(NAME parse_version_string-cmake_t
  COMMAND ${CMAKE_COMMAND}
  -DCMAKE_MODULE_PATH:STRING=${CMAKE_CURRENT_SOURCE_DIR}/../../Modules
  -P${CMAKE_CURRENT_SOURCE_DIR}/parse_version_string_t.cmake
  )

add_test(NAME version_cmp-cmake_t
  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/version_cmp-cmake_t)
