configure_file(FindBuildSystemPackage.cmake.in
  FindBuildSystemPackage.cmake
  @ONLY
)
install(DIRECTORY ./ DESTINATION Modules
  FILES_MATCHING PATTERN "*.cmake" PATTERN "[.#]*.cmake" EXCLUDE)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/FindBuildSystemPackage.cmake
  DESTINATION Modules)
