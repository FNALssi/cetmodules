cmake_minimum_required(VERSION 3.18.2...3.20 FATAL_ERROR)
include(Compatibility)
macro(check_prod_version PRODUCT VERSION MINIMUM)
  warn_deprecated("check_prod_version()" NEW
    "cet_compare_versions(RESULT_VAR VERSION VERSION_<cmp> MINIMUM), \
cet_version_cmp(RESULT_VAR VERSION MINIMUM), if (X VERSION_cmp Y)...\
")
  if (CET_WARN_DEPRECATED)
    set(_cpv_deprecations_disabled TRUE)
    unset(CET_WARN_DEPRECATED)
  endif()
  check_ups_version(${ARGV})
  if (_cpv_deprecations_disabled)
    set(CET_WARN_DEPRECATED TRUE)
    unset(_cpv_deprecations_disabled)
  endif()
endmacro()

