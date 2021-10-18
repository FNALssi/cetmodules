set(CACHE_METADATA 0)
configure_file(${CPAN_CONFIG_DIR}/${CPAN_CONFIG_TEMPLATE}
  ${CPAN_INSTALL_DIR}/MyConfig.pm @ONLY)

# Set the environment for commands.
string(JOIN ":" env_path "${CPAN_INSTALL_DIR}/bin" $ENV{PATH})
string(JOIN ":" env_perl5lib "${CPAN_INSTALL_DIR}/lib/perl5" $ENV{PERL5LIB})
string(JOIN ":" env_perl_local_lib_root "${CPAN_INSTALL_DIR}" $ENV{PERL_LOCAL_LIB_ROOT})
set(ENV{PATH} "${env_path}")
set(ENV{PERL5LIB} "${env_perl5lib}")
set(ENV{PERL_LOCAL_LIB_ROOT} "${env_perl_local_lib_root}")
set(ENV{PERL_MB_OPT} "--install_base \"${CPAN_INSTALL_DIR}\"")
set(ENV{PERL_MM_OPT} "INSTALL_BASE=${CPAN_INSTALL_DIR}")


execute_process(COMMAND perl -I. -MCPAN -e
  "CPAN::Shell->notest(\"install\", \
\"Digest::SHA\", \
\"List::MoreUtils\", \
\"List::Util\", \
\"Module::ScanDeps\" \
\"Readonly\", \
\"Storable\", \
\"Test::More\", \
)\
"
  COMMAND_ECHO STDERR
  COMMAND_ERROR_IS_FATAL ANY
  )
