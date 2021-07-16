set(cetmodules_bootstrap_version ${cetmodules_VERSION})
set(cetbuildtools_bootstrap_version ${cetmodules_MIN_CETBUILDTOOLS_VERSION})
foreach(pkg IN ITEMS modules buildtools)
  set(bootstrap_package cet${pkg})
  set(bootstrap_version ${${bootstrap_package}_bootstrap_version})
  configure_file(Bootstrap.cmake.in BootstrapCet${pkg}.cmake @ONLY)
  list(APPEND generated_modules
    "${CMAKE_CURRENT_BINARY_DIR}/BootstrapCet${pkg}.cmake")
endforeach()

file(READ "${CMAKE_ROOT}/Modules/WriteBasicConfigVersionFile.cmake" content)
string(REPLACE "WRITE_BASIC_CONFIG_VERSION_FILE"
  "cet_write_package_version_file" content "${content}")
string(REPLACE "\${CMAKE_ROOT}/Modules/BasicConfigVersion"
  "\${cetmodules_CONFIG_DIR}/CetConfigVersion"
  content "${content}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/CetWritePackageVersionFile.cmake" "${content}")
list(APPEND generated_modules
  "${CMAKE_CURRENT_BINARY_DIR}/CetWritePackageVersionFile.cmake")

install(DIRECTORY ./ DESTINATION Modules
  FILES_MATCHING PATTERN "*.cmake" PATTERN "[.#]*.cmake" EXCLUDE)

install(FILES ${generated_modules} DESTINATION Modules)
