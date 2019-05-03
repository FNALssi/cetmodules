include(CetProjectVars)

cet_project_var(config_dir config
  DOCSTRING "Directory containing cetmodules CMakeConfig.cmake fragments")

INSTALL (FILES
  product-config.cmake.in.middle
  product-config.cmake.in.bottom
  UPS_PRODUCT_VERSION_FILE.in
  DESTINATION config)
