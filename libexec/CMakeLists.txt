##################
# Scripts for internal use only.
##################

project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

set(private_programs
  cet_exec_test
  checkClassVersion
  filter-output
  filter-program-options
  fix-man-dirs
  remove_deleted_header_refs)

set(legacy_private_programs
  cmake-graphviz-filt
  set_dev_products
  verify_build_environment)

set(legacy_private_files parse_deps.pm pass fail)

cet_script(${private_programs} ${legacy_private_programs}
  DESTINATION ${cetmodules_LIBEXEC_DIR})

install(FILES ${legacy_private_files}
  DESTINATION ${cetmodules_LIBEXEC_DIR})
