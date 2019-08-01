##################
# Publicly-available scripts.
##################

set(public_programs
  format-code
  make_bash_completions)

set(legacy_public_programs
  buildtool
  code-dep-graph
  increment-version)

set(public_files cet_test_functions.sh)

cet_script(${public_programs} ${legacy_public_programs})

install(FILES ${public_files} DESTINATION ${cetmodules_BIN_DIR})
