#[================================================================[.rst:
CetFindPackage
==============
#]================================================================]
include_guard()
cmake_minimum_required(VERSION 3.18.2...3.22 FATAL_ERROR)

include(Compatibility)
macro(cet_find_package)
  warn_deprecated(cet_find_package
    "\nNOTE: use find_package() (overridden by cetmodules)")
  if (NOT "${ARGV}" MATCHES "(^|;)(BUILD_ONLY|INTERFACE|PRIVATE|PUBLIC)(;|$)")
    # Backwards compatibility: cet_find_package() defaulted to PUBLIC;
    # find_package defaults to PRIVATE.
    set(_cet_cfp_public PUBLIC)
  else()
    unset(_cet_cfp_public)
  endif()
  find_package(${ARGV} ${_cet_cfp_public})
endmacro()

