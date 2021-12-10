file(COPY_FILE ${CMAKE_CURRENT_SOURCE_DIR}/cmake-required-version.txt
  ${CMAKE_CURRENT_BINARY_DIR}/cmake-required-version.txt ONLY_IF_DIFFERENT)

file(INSTALL ${CMAKE_CURRENT_SOURCE_DIR}/cmake-required-version.txt
  DESTINATION etc)
