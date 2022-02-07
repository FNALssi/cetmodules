##################
# Scripts for internal use only.
##################

project_variable(CPAN_DIR CONFIG ${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}/CPAN)
project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

if (WANT_UPS)
  set(cpan_tmp
    "${PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}/.cpan/tmp")
  add_custom_command(OUTPUT "${cpan_tmp}/CPAN.stamp"
    COMMAND bootstrap-perl-env
    DEPFILE "${cpan_tmp}/CPAN.d"
    COMMENT "Obtain Perl prerequisites for ${CETMODULES_CURRENT_PROJECT_NAME}"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
    VERBATIM)
  add_custom_target(perl-prereq ALL DEPENDS "${cpan_tmp}/CPAN.stamp" VERBATIM)
  # Bundle required Perl modules.
  install(DIRECTORY ${PROJECT_BINARY_DIR}/${${CETMODULES_CURRENT_PROJECT_NAME}_CPAN_DIR}/
    DESTINATION ${${CETMODULES_CURRENT_PROJECT_NAME}_CPAN_DIR})
endif()

set(private_programs
  bootstrap-perl-env
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

set(legacy_private_files pass fail)

cet_script(${private_programs} ${legacy_private_programs}
  DESTINATION ${cetmodules_LIBEXEC_DIR})

install(FILES ${private_files} ${legacy_private_files}
  DESTINATION ${cetmodules_LIBEXEC_DIR})

# Install Perl modules.
install(DIRECTORY ./ DESTINATION ${cetmodules_LIBEXEC_DIR}
  FILES_MATCHING PATTERN "*.pm")
