# We do not install source
#

include(CMakeParseArguments)
include(CetCurrentSubdir)

macro( install_source   )
  cmake_parse_arguments( ISRC "" "" "SUBDIRS;LIST;EXTRAS;EXCLUDES" ${ARGN})
  #message( STATUS "install_source: PACKAGE_TOP_DIRECTORY is ${PACKAGE_TOP_DIRECTORY}")
  _cet_current_subdir( CURRENT_SUBDIR )
  set(source_install_dir ${product}/${version}/source${CURRENT_SUBDIR} )
  ##message( STATUS "install_source: source code will be installed in ${source_install_dir}" )
  message(STATUS "install_source is not yet implemented")
endmacro( install_source )
