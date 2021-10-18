# These source-able files are required by the table file to set the
# correct environment to find our bundled Perl modules.
install(FILES perl-env.sh perl-env.csh
  DESTINATION ${${CETMODULES_CURRENT_PROJECT_NAME}_UPS_PRODUCT_TABLE_SUBDIR})
