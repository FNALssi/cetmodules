# parse product_deps and qualifier_deps

# product_deps format:

#   parent       this_product   this_version
#   [incdir      product_dir    include]
#   [fcldir      product_dir    fcl]
#   [libdir      fq_dir	        lib]
#   [bindir      fq_dir         bin]
#   [fwdir       -              unspecified]
#   [gdmldir     -              gdml]
#   [perllib     -              perl5lib]
#   [testdir     product_dir    test]
#
#   product		version
#   dependent_product	dependent_product_version [optional]
#   dependent_product	dependent_product_version [optional]
#
#   qualifier dependent_product       dependent_product notes
#   this_qual dependent_product_qual  dependent_product_qual
#   this_qual dependent_product_qual  dependent_product_qual

# The indir, fcldir, libdir, and bindir lines are optional
# Use them only if your product does not conform to the defaults
# Format: directory_type directory_path directory_name
# The only recognized values of the first field are incdir, fcldir, libdir, and bindir
# The only recognized values of the second field are product_dir and fq_dir
# The third field is not constrained
#
# if dependent_product_version is a dash, the "current" version will be specified
# If a dependent product is optional, then add "optional" to the third field. 

#
# Use as many rows as you need for the qualifiers
# Use a separate column for each dependent product that must be explicitly setup
# Do not list products which will be setup by a dependent_product
#
# special qualifier options
# -	not installed for this parent qualifier
# -nq-	this dependent product has no qualifier
# -b-	this dependent product is only used for the build - it will not be in the table

use strict;
use warnings;

use List::Util qw(min max); # Numeric min / max funcions.

sub get_cmake_bin_directory {
  my @params = @_;
  my $bindir = "DEFAULT";
  my $line;
  my $binsubdir;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "bindir" ) {
	 if( $#words < 2 ) {
	   $binsubdir = "bin";
	 } else {
	   $binsubdir = $words[2];
	 }
         if( $words[1] eq "product_dir" ) {
	    $bindir = "product_dir/$binsubdir";
         } elsif( $words[1] eq "fq_dir" ) {
	    $bindir = "flavorqual_dir/$binsubdir";
         } elsif( $words[1] eq "-" ) {
	    $bindir = "NONE";
	 } else {
	    $bindir = "ERROR";
	 }
      }
    }
  }
  close(PIN);
  return ($bindir);
}

sub get_cmake_lib_directory {
  my @params = @_;
  my $libdir = "DEFAULT";
  my $line;
  my $libsubdir;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "libdir" ) {
	 if( $#words < 2 ) {
	   $libsubdir = "lib";
	 } else {
	   $libsubdir = $words[2];
	 }
         if( $words[1] eq "product_dir" ) {
	    $libdir = "product_dir/$libsubdir";
         } elsif( $words[1] eq "fq_dir" ) {
	    $libdir = "flavorqual_dir/$libsubdir";
         } elsif( $words[1] eq "-" ) {
	    $libdir = "NONE";
	 } else {
	    $libdir = "ERROR";
	 }
      }
    }
  }
  close(PIN);
  return ($libdir);
}

sub get_cmake_inc_directory {
  my @params = @_;
  my $incdir = "DEFAULT";
  my $line;
  my $incsubdir;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "incdir" ) {
	 if( $#words < 2 ) {
	   $incsubdir = "include";
	 } else {
	   $incsubdir = $words[2];
	 }
         if( $words[1] eq "product_dir" ) {
	    $incdir = "product_dir/$incsubdir";
         } elsif( $words[1] eq "fq_dir" ) {
	    $incdir = "flavorqual_dir/$incsubdir";
         } elsif( $words[1] eq "-" ) {
	    $incdir = "NONE";
	 } else {
	    $incdir = "ERROR";
	 }
      }
    }
  }
  close(PIN);
  return ($incdir);
}

sub get_cmake_fcl_directory {
  my @params = @_;
  my $fcldir = "DEFAULT";
  my $line;
  my $fclsubdir;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "fcldir" ) {
	 if( $#words < 2 ) {
	   $fclsubdir = "fcl";
	 } else {
	   $fclsubdir = $words[2];
	 }
         if( $words[1] eq "product_dir" ) {
	    $fcldir = "product_dir/$fclsubdir";
         } elsif( $words[1] eq "fq_dir" ) {
	    $fcldir = "flavorqual_dir/$fclsubdir";
         } elsif( $words[1] eq "-" ) {
	    $fcldir = "NONE";
	 } else {
	    $fcldir = "ERROR";
	 }
      }
    }
  }
  close(PIN);
  return ($fcldir);
}

sub get_cmake_fw_directory {
  my @params = @_;
  my $fwdir = "NONE";
  my $line;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "fwdir" ) {
         if( $words[1] eq "-" ) {
	     $fwdir = "NONE";
	 } else { 
            if( ! $words[2] ) { 
	       $fwdir = "ERROR";
	    } else {
	       my $fwsubdir = $words[2];
               if( $words[1] eq "product_dir" ) {
		  $fwdir = "product_dir/$fwsubdir";
               } elsif( $words[1] eq "fq_dir" ) {
		  $fwdir = "flavorqual_dir/$fwsubdir";
	       } else {
		  $fwdir = "ERROR";
	       }
	    }
	 }
      }
    }
  }
  close(PIN);
  return ($fwdir);
}

sub get_cmake_setfw_list {
  my @params = @_;
  my $setfwdir = "NONE";
  my @fwlist;
  my $fwiter=-1;
  my $line;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "set_fwdir" ) {
         ++$fwiter;
         if( $words[1] eq "-" ) {
	     $setfwdir = "NONE";
	 } else { 
            if( ! $words[2] ) { 
               if( $words[1] eq "product_dir" ) {
		  $setfwdir = "product_dir";
               } elsif( $words[1] eq "fq_dir" ) {
		  $setfwdir = "flavorqual_dir";
	       } else {
		  $setfwdir = "ERROR";
	       }
	    } else {
	       my $fwsubdir = $words[2];
               if( $words[1] eq "product_dir" ) {
		  $setfwdir = "product_dir/$fwsubdir";
               } elsif( $words[1] eq "fq_dir" ) {
		  $setfwdir = "flavorqual_dir/$fwsubdir";
	       } else {
		  $setfwdir = "ERROR";
	       }
	    }
	 }
	 $fwlist[$fwiter]=$setfwdir;
      }
    }
  }
  close(PIN);
  return ($fwiter, \@fwlist);
}

sub get_cmake_gdml_directory {
  my @params = @_;
  my $gdmldir = "NONE";
  my $line;
  my $gdmlsubdir;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "gdmldir" ) {
	 if( $#words < 2 ) {
	   $gdmlsubdir = "gdml";
	 } else {
	   $gdmlsubdir = $words[2];
	 }
         if( $words[1] eq "product_dir" ) {
	    $gdmldir = "product_dir/$gdmlsubdir";
         } elsif( $words[1] eq "fq_dir" ) {
	    $gdmldir = "flavorqual_dir/$gdmlsubdir";
         } elsif( $words[1] eq "-" ) {
	    $gdmldir = "NONE";
	 } else {
	    $gdmldir = "ERROR";
	 }
      }
    }
  }
  close(PIN);
  return ($gdmldir);
}

sub get_cmake_perllib {
  my @params = @_;
  my $prldir = "NONE";
  my $line;
  my $prlsubdir;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "perllib" ) {
	 if( $#words < 2 ) {
	   $prlsubdir = "perllib";
	 } else {
	   $prlsubdir = $words[2];
	 }
         if( $words[1] eq "product_dir" ) {
	    $prldir = "product_dir/$prlsubdir";
         } elsif( $words[1] eq "fq_dir" ) {
	    $prldir = "flavorqual_dir/$prlsubdir";
         } elsif( $words[1] eq "-" ) {
	    $prldir = "NONE";
	 } else {
	    $prldir = "ERROR";
	 }
      }
    }
  }
  close(PIN);
  return ($prldir);
}

sub get_cmake_test_directory {
  my @params = @_;
  my $testdir = "DEFAULT";
  my $line;
  my $testsubdir;
  open(PIN, "< $params[0]") or die "Couldn't open $params[0]";
  while ( $line=<PIN> ) {
    chop $line;
    if ( index($line,"#") == 0 ) {
    } elsif ( $line !~ /\w+/ ) {
    } else {
      my @words = split(/\s+/,$line);
      if( $words[0] eq "testdir" ) {
	 if( $#words < 2 ) {
	   $testsubdir = "test";
	 } else {
	   $testsubdir = $words[2];
	 }
         if( $words[1] eq "product_dir" ) {
	    $testdir = "product_dir/$testsubdir";
         } elsif( $words[1] eq "fq_dir" ) {
	    $testdir = "flavorqual_dir/$testsubdir";
         } elsif( $words[1] eq "-" ) {
	    $testdir = "NONE";
	 } else {
	    $testdir = "ERROR";
	 }
      }
    }
  }
  close(PIN);
  return ($testdir);
}

1;
