##################
# Publicly-available scripts.
##################

set(public_programs
  #  filter-output
  #  format-code
  #  intersphinx-refs
  make_bash_completions
)

set(legacy_public_programs
#  buildtool
#  code-dep-graph
#  increment-version
)

set(legacy_compat
#  set_dev_products
#  set_dev_lib
#  set_dev_bin
#  set_dev_fhicl
#  set_dev_fwsearch
#  set_dev_check_report
)

#set(public_files cet_test_functions.sh)

if (public_programs OR legacy_public_programs)
  cet_script(${public_programs} ${legacy_public_programs})
endif()

if (public_files)
  install(FILES ${public_files} DESTINATION ${cetmodules_BIN_DIR})
endif()

if (legacy_compat)
  install(PROGRAMS ${legacy_compat} DESTINATION ${cetmodules_BIN_DIR})
endif()
