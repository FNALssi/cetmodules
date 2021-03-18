configure_file(BootstrapCetmodules.cmake.in
  BootstrapCetmodules.cmake
  @ONLY
)
configure_file(BootstrapCetbuildtools.cmake.in
  BootstrapCetbuildtools.cmake
  @ONLY
)
install(DIRECTORY ./ DESTINATION Modules
  FILES_MATCHING PATTERN "*.cmake" PATTERN "[.#]*.cmake" EXCLUDE)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/BootstrapCetmodules.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/BootstrapCetbuildtools.cmake
  DESTINATION Modules)
