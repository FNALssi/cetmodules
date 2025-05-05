project_variable(
  ETC_DIR "etc" CONFIG DOCSTRING
  "Installation location for miscellaneous files"
  )

configure_file(cmake_required_version.txt . @ONLY)

install(FILES CompileOnlyTest.cmake.in CompileOnlyTest.in
              ${CMAKE_CURRENT_BINARY_DIR}/cmake_required_version.txt
        DESTINATION ${cetmodules_ETC_DIR}
        )
