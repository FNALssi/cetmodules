########################################################################
# Generate templates and shell-agnostic scripts with which to populate a
# package's ups/ directory.
########################################################################

cet_timestamp(GEN_TIME)

# product_deps template.
configure_file(product_deps.template.in product_deps.template @ONLY)

# setup_deps.
set(nobuild nobuild)
configure_file(setup.in setup_deps @ONLY)

# setup_for_development.
set(nobuild)
configure_file(setup.in setup_for_development @ONLY)

install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/product_deps.template
  ${CMAKE_CURRENT_BINARY_DIR}/setup_for_development
  ${CMAKE_CURRENT_BINARY_DIR}/setup_deps
  README
  DESTINATION ups-templates)
