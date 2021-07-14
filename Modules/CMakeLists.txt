configure_file(BootstrapCetmodules.cmake.in
  BootstrapCetmodules.cmake
  @ONLY
)
configure_file(BootstrapCetbuildtools.cmake.in
  BootstrapCetbuildtools.cmake
  @ONLY
)

file(READ "${CMAKE_ROOT}/Modules/WriteBasicConfigVersionFile.cmake" content)
string(REPLACE "WRITE_BASIC_CONFIG_VERSION_FILE"
  "cet_write_package_version_file" content "${content}")
string(REPLACE "\${CMAKE_ROOT}/Modules/BasicConfigVersion"
  "\${cetmodules_CONFIG_DIR}/CetConfigVersion"
  content "${content}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/private/CetWritePackageVersionFile.cmake" "${content}")
list(APPEND generated_private_modules
  "${CMAKE_CURRENT_BINARY_DIR}/private/CetWritePackageVersionFile.cmake")

install(DIRECTORY ./ DESTINATION Modules
  FILES_MATCHING PATTERN "*.cmake" PATTERN "[.#]*.cmake" EXCLUDE)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/BootstrapCetmodules.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/BootstrapCetbuildtools.cmake
  DESTINATION Modules)

install(FILES ${generated_private_modules}
  DESTINATION Modules/private)
