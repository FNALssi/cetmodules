include(CetMake)
install(PROGRAMS 
  checkClassVersion
  cet_test_functions.sh
  filter-program-options
  filter-output
  format-code
  make_bash_completions
  DESTINATION bin)

cet_script(cet_exec_test)
