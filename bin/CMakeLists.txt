##################
# Publicly-available scripts.
##################

set(public_programs
  format-code
  intersphinx-refs
  make_bash_completions)

set(legacy_public_programs
  buildtool
  code-dep-graph
  increment-version)

set(legacy_compat
  set_dev_products
  set_dev_lib
  set_dev_bin
  set_dev_fhicl
  set_dev_fwsearch
  set_dev_check_report)

set(public_files cet_test_functions.sh)

cet_script(${public_programs} ${legacy_public_programs})

install(FILES ${public_files} DESTINATION ${cetmodules_BIN_DIR})
install(PROGRAMS ${legacy_compat} DESTINATION ${cetmodules_BIN_DIR})
