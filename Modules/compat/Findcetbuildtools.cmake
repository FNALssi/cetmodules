set(cetbuildtools_VERSION 7.17.01)
set(cetbuildtools_UPS_VERSION v7_17_01)

set(CET_WARN_DEPRECATED) # Quiet warnings for known old package.

find_package(cetmodules NO_MODULE REQUIRED)

set(cetbuildtools_BINDIR ${cetmodules_BINARY_DIR})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(cetmodules CONFIG_MODE NAME_MISMATCHED
  REQUIRED_VARS CET_EXEC_TEST)
