#[================================================================[.rst:
CheckUpsVersion
===============
#]================================================================]
# Avoid unwanted repeat inclusion.
include_guard()

cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(Compatibility)
include(ParseVersionString)

function(check_ups_version PRODUCT VERSION MINIMUM)
  warn_deprecated("check_ups_version()" NEW "cet_compare_versions(RESULT_VAR VERSION VERSION_<cmp> MINIMUM), if (X VERSION_cmp Y)...")
  cmake_parse_arguments(PARSE_ARGV 3 CUV "" "PRODUCT_OLDER_VAR;PRODUCT_MATCHES_VAR" "")
  if (NOT (CUV_PRODUCT_OLDER_VAR OR CUV_PRODUCT_MATCHES_VAR))
    message(FATAL_ERROR "at least one of PRODUCT_OLDER_VAR and PRODUCT_MATCHES_VAR is required")
  endif()
  cet_version_cmp(_cuv_result ${VERSION} ${MINIMUM})
  if (_cuv_result EQUAL -1)
    if (CUV_PRODUCT_OLDER_VAR)
      set(${CUV_PRODUCT_OLDER_VAR} TRUE PARENT_SCOPE)
    endif()
    if (CUV_PRODUCT_MATCHES_VAR)
      set(${CUV_PRODUCT_MATCHES_VAR} FALSE PARENT_SCOPE)
    endif()
  else()
    if (CUV_PRODUCT_MATCHES_VAR)
      set(${CUV_PRODUCT_MATCHES_VAR} TRUE PARENT_SCOPE)
    endif()
    if (CUV_PRODUCT_OLDER_VAR)
      set(${CUV_PRODUCT_OLDER_VAR} FALSE PARENT_SCOPE)
    endif()
  endif()
endfunction()
