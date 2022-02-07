eval "_cet_fq_dir_var=\"\${${UPS_PROD_NAME_UC}_FQ_DIR}\""
eval " `perl -I\"$_cet_fq_dir_var/CPAN/lib/perl5\" -Mlocal::lib=\"$_cet_fq_dir_var/CPAN\"`"
unset _cet_fq_dir_var
