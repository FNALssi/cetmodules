#[================================================================[.rst:
CetFindPackage
--------------
#]================================================================]
include_guard()
cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

include(Compatibility)
macro(cet_find_package)
  warn_deprecated(cet_find_package
    "\nNOTE: use find_package() (overridden by cetmodules)")
  if (NOT "${ARGV}" MATCHES "(^|;)(BUILD_ONLY|INTERFACE|PRIVATE|PUBLIC|EXPORT)(;|$)")
    # Backwards compatibility: cet_find_package() defaulted to EXPORT.
    set(_cet_cfp_export EXPORT)
  else()
    unset(_cet_cfp_export)
  endif()
  find_package(${ARGV} ${_cet_cfp_export})
endmacro()

