########################################################################
#
# install_headers()
#   Install headers for inclusion by other packages.
#   Default extensions:
#      .h .hh .H .hpp .icc .tcc
#

include(CMakeParseArguments)
include(CetCurrentSubdir)

macro( _cet_check_inc_directory )
  if( ${${product}_inc_dir} MATCHES "NONE" )
     message(FATAL_ERROR "Please specify an include directory in product_deps")
  elseif( ${${product}_inc_dir} MATCHES "ERROR" )
     message(FATAL_ERROR "Invalid include directory in product_deps")
  endif()
endmacro( _cet_check_inc_directory )

macro( _cet_check_build_directory_for_headers )
  FILE(GLOB build_directory_headers
	    ${CMAKE_CURRENT_BINARY_DIR}/[^.]*.h
	    ${CMAKE_CURRENT_BINARY_DIR}/[^.]*.hh
	    ${CMAKE_CURRENT_BINARY_DIR}/[^.]*.H
	    ${CMAKE_CURRENT_BINARY_DIR}/[^.]*.hpp
	    ${CMAKE_CURRENT_BINARY_DIR}/[^.]*.icc
	    ${CMAKE_CURRENT_BINARY_DIR}/[^.]*.tcc
	    )
  if( build_directory_headers )
    INSTALL( FILES ${build_directory_headers}
             DESTINATION ${header_install_dir} )
  endif( build_directory_headers )
endmacro( _cet_check_build_directory_for_headers )

macro( _cet_install_header_without_list   )
  #message( STATUS "headers will be installed in ${header_install_dir}" )
  FILE(GLOB headers [^.]*.h [^.]*.hh [^.]*.H [^.]*.hpp [^.]*.icc [^.]*.tcc )
  FILE(GLOB dict_headers classes.h )
  if( dict_headers )
    #message(STATUS "install_headers debug: removing ${dict_headers} from header list")
    # no special handling needed, since these filenames already have the full path
    LIST(REMOVE_ITEM headers ${dict_headers} )
  endif( dict_headers)
  if(IHDR_EXCLUDES)
    _cet_exclude_from_list( headers EXCLUDES ${IHDR_EXCLUDES} LIST ${headers} )
  endif()
  if( headers )
    #message( STATUS "installing headers ${headers} in ${header_install_dir}")
    INSTALL( FILES ${headers}
             DESTINATION ${header_install_dir} )
  endif( headers )
  # now check subdirectories
  if( IHDR_SUBDIRS )
    foreach( sub ${IHDR_SUBDIRS} )
      FILE(GLOB subdir_headers
                ${sub}/[^.]*.h ${sub}/[^.]*.hh ${sub}/[^.]*.H ${sub}/[^.]*.hpp ${sub}/[^.]*.icc ${sub}/[^.]*.tcc )
      if(IHDR_EXCLUDES)
        _cet_exclude_from_list( subdir_headers EXCLUDES ${IHDR_EXCLUDES} LIST ${subdir_headers} )
      endif()
      if( subdir_headers )
        INSTALL( FILES ${subdir_headers}
                 DESTINATION ${header_install_dir}/${sub} )
      endif( subdir_headers )
    endforeach(sub)
    #message( STATUS "also installing in subdirectories: ${IHDR_SUBDIRS}")
  endif( IHDR_SUBDIRS )
endmacro( _cet_install_header_without_list )

macro( _cet_install_header_from_list header_list  )
  ##message( STATUS "_cet_install_header_from_list debug: source code list will be installed in ${header_install_dir}" )
  ##message( STATUS "_cet_install_header_from_list debug: install list is ${header_list}")
  INSTALL( FILES ${header_list}
           DESTINATION ${header_install_dir} )
endmacro( _cet_install_header_from_list )

macro( install_headers   )
  cmake_parse_arguments( IHDR "USE_PRODUCT_NAME" "" "SUBDIRS;LIST;EXTRAS;EXCLUDES" ${ARGN})
  _cet_current_subdir( CURRENT_SUBDIR )
  _cet_check_inc_directory()
  if (IHDR_USE_PRODUCT_NAME OR ART_MAKE_PREPEND_PRODUCT_NAME)
    set(header_install_dir ${${product}_inc_dir}/${product}${CURRENT_SUBDIR} )
  else()
    set(header_install_dir ${${product}_inc_dir}${CURRENT_SUBDIR} )
  endif()
  ##message( STATUS "install_headers: ART_MAKE_PREPEND_PRODUCT_NAME is  ${ART_MAKE_PREPEND_PRODUCT_NAME}" )
  ##message( STATUS "install_headers: IHDR_USE_PRODUCT_NAME is  ${IHDR_USE_PRODUCT_NAME}" )
  ##message( STATUS "install_headers: PACKAGE_TOP_DIRECTORY is  ${PACKAGE_TOP_DIRECTORY}" )
  ##message( STATUS "install_headers: CMAKE_SOURCE_DIR is  ${CMAKE_SOURCE_DIR}" )
  ##message( STATUS "install_headers: CMAKE_CURRENT_SOURCE_DIR is  ${CMAKE_CURRENT_SOURCE_DIR}" )
  message( STATUS "install_headers: headers will be installed in ${header_install_dir}" )
  if( IHDR_LIST )
    if( IHDR_SUBDIRS )
      message( FATAL_ERROR
               "ERROR: call install_headers with EITHER LIST or SUBDIRS but not both")
    endif( IHDR_SUBDIRS )
    _cet_install_header_from_list("${IHDR_LIST}")
  else()
    if( IHDR_EXTRAS )
      _cet_install_header_from_list("${IHDR_EXTRAS}")
    endif( IHDR_EXTRAS )
    _cet_install_header_without_list()
  endif()

  _cet_check_build_directory_for_headers()

endmacro( install_headers )
