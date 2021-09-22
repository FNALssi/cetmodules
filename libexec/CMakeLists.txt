##################
# Scripts for internal use only.
##################

project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

set(private_programs
  cet_exec_test
  cet_lock
  checkClassVersion
  filter-output
  filter-program-options
  fix-man-dirs
  remove_deleted_header_refs)

set(legacy_private_programs
  cmake-graphviz-filt
  set_dev_products
  verify_build_environment)

set(private_files message_functions.sh)

set(legacy_private_files parse_deps.pm pass fail)

cet_script(${private_programs} ${legacy_private_programs}
  DESTINATION ${cetmodules_LIBEXEC_DIR})

install(FILES ${private_files} ${legacy_private_files}
  DESTINATION ${cetmodules_LIBEXEC_DIR})
