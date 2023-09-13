#[================================================================[.rst:
CheckProdVersion
================
#]================================================================]
include_guard()
cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(Compatibility)
macro(check_prod_version PRODUCT VERSION MINIMUM)
  warn_deprecated("check_prod_version()" NEW
    "cet_compare_versions(RESULT_VAR VERSION VERSION_<cmp> MINIMUM), \
cet_version_cmp(RESULT_VAR VERSION MINIMUM), if (X VERSION_cmp Y)...\
")
  cet_without_deprecation_warnings(check_ups_version ${ARGV})
endmacro()
