##################
# Scripts for internal use only.
##################

include(CetMake) # for cet_script()

project_variable(LIBEXEC_DIR CONFIG ${CMAKE_INSTALL_LIBEXECDIR})

set(private_programs
  cet_exec_test
  checkClassVersion
  filter-program-options
  fix-man-dirs
)

cet_script(${private_programs} DESTINATION ${cetmodules_LIBEXEC_DIR})
