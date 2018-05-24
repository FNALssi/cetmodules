include(CetMake)
INSTALL (PROGRAMS 
  checkClassVersion
  cet_report
  filter-program-options
  filter-output
  make_bash_completions
  report_fcldir_base
  report_product_info
  report_setfw
  DESTINATION bin)

INSTALL ( FILES cmake_parse_deps.pm DESTINATION bin )

cet_script(cet_exec_test)
