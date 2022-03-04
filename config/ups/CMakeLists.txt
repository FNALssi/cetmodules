install(FILES
  CMakePresets.json.in
  perl-env.csh
  perl-env.sh
  product-chain-file.in
  product-version-file.in
  product.table.top.in
  product.table.bottom.in
  DESTINATION ${${CETMODULES_CURRENT_PROJECT_NAME}_CONFIG_DIR}/ups)
