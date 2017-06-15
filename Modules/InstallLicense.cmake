########################################################################
# install_license()
# install LICENSE and README
#
####################################
# Recommended use:
#
# install_license()
#
########################################################################


macro( install_license   )
  FILE(GLOB license_files
	    README LICENSE
	    )
  if( license_files )
    INSTALL( FILES ${license_files}
             DESTINATION . )
  endif( license_files )
endmacro( install_license )
