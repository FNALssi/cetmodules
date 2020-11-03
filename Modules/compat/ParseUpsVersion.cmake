
# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)
cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(Compatibility)

macro(parse_ups_version UPS_VERSION)
  warn_deprecated("parse_ups_version()" NEW "parse_version_string(${UPS_VERSION} VMAJ VMIN VPRJ VPT)")
  parse_version_string(${UPS_VERSION} VMAJ VMIN VPRJ VPT)
endmacro()

cmake_policy(POP)
