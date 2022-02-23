##################
# Scripts for internal use only.
##################

project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

if (WANT_UPS)
  project_variable(CPAN_DIR CONFIG CPAN)
  cmake_path(APPEND PROJECT_BINARY_DIR
    ${${CETMODULES_CURRENT_PROJECT_NAME}_EXEC_PREFIX}
    .cpan
    tmp
    CPAN.stamp
    OUTPUT_VARIABLE _cpan_stamp)
  cmake_path(REPLACE_EXTENSION _cpan_stamp LAST_ONLY d OUTPUT_VARIABLE _cpan_deps)
  add_custom_command(OUTPUT "${_cpan_stamp}"
    COMMAND bootstrap-perl-env
    DEPFILE "${_cpan_deps}"
    COMMENT "Obtain Perl prerequisites for ${CETMODULES_CURRENT_PROJECT_NAME}"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
    VERBATIM)
  add_custom_target(perl-prereq ALL DEPENDS "${_cpan_stamp}" VERBATIM)
  # Bundle required Perl modules.
  cmake_path(APPEND PROJECT_BINARY_DIR
    ${${CETMODULES_CURRENT_PROJECT_NAME}_CPAN_DIR}
    OUTPUT_VARIABLE _cpan_dir)
  install(DIRECTORY ${_cpan_dir}/
    USE_SOURCE_PERMISSIONS
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
