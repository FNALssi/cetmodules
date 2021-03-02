set(cetbuildtools_VERSION 8.00.00)
set(cetbuildtools_UPS_VERSION v8_00_00)

find_package(cetmodules 2.10.00 NO_MODULE REQUIRED)

include(Compatibility)
set(CET_WARN_DEPRECATED) # Quiet warnings for known old package.
set(cetbuildtools_BINDIR ${cetmodules_BINARY_DIR})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(cetmodules CONFIG_MODE NAME_MISMATCHED
  REQUIRED_VARS CET_EXEC_TEST)
