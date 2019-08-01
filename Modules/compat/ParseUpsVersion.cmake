include(Compatibility)

macro(parse_ups_version UPS_VERSION)
  warn_deprecated("parse_ups_version()" NEW "parse_version_string(${UPS_VERSION} VMAJ VMIN VPRJ VPT)")
  parse_version_string(${UPS_VERSION} VMAJ VMIN VPRJ VPT)
endmacro()

