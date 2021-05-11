add_test(NAME parse_version_string-cmake_t
  COMMAND ${CMAKE_COMMAND}
  -DCMAKE_MODULE_PATH:STRING=${CMAKE_CURRENT_LIST_DIR}/../../Modules
  -P${CMAKE_CURRENT_LIST_DIR}/parse_version_string_t.cmake
  )
