# cet_make
#
# Identify the files in the current source directory and deal with them appropriately
# Users may opt to just include cet_make() in their CMakeLists.txt
# This implementation is intended to be called NO MORE THAN ONCE per subdirectory.
#
########################################################################
cmake_policy(VERSION 3.0.1) # We've made this work for 3.0.1.

macro( _cet_check_lib_directory )
  if( ${${product}_lib_dir} MATCHES "NONE" )
      message(FATAL_ERROR "Please specify a lib directory in product_deps")
  elseif( ${${product}_lib_dir} MATCHES "ERROR" )
      message(FATAL_ERROR "Invalid lib directory in product_deps")
  endif()
  message(STATUS "${product}_lib_dir is ${${product}_lib_dir}")
endmacro( _cet_check_lib_directory )

macro( cet_make_library )
  set(cet_file_list "")
  set(cet_make_library_usage "USAGE: cet_make_library( LIBRARY_NAME <library name> SOURCE <source code list> [LIBRARIES <library link list>] )")
  message(STATUS "cet_make_library debug: called with ${ARGN} from ${CMAKE_CURRENT_SOURCE_DIR}")
  cmake_parse_arguments( CML "WITH_STATIC_LIBRARY;NO_INSTALL" "LIBRARY_NAME" "LIBRARIES;SOURCE" ${ARGN})
  # there are no default arguments
  if( CML_DEFAULT_ARGS )
    message(FATAL_ERROR  " undefined arguments ${CML_DEFAULT_ARGS} \n ${cet_make_library_usage}")
  endif()
  # check for a source code list
  if(CML_SOURCE)
    set(cet_src_list ${CML_SOURCE})
  else()
    message(FATAL_ERROR  "SOURCE is required \n ${cet_make_library_usage}")
  endif()
  # verify that the library name has been specified
  if(CML_LIBRARY_NAME)
    add_library( ${CML_LIBRARY_NAME} SHARED ${cet_src_list} )
  else()
    message(FATAL_ERROR  "LIBRARY_NAME is required \n ${cet_make_library_usage}")
  endif()
  if(CML_LIBRARIES)
    set(cml_lib_list "")
    foreach (lib ${CML_LIBRARIES})
      string(REGEX MATCH [/] has_path "${lib}")
      if( has_path )
        list(APPEND cml_lib_list ${lib})
      else()
        string(TOUPPER  ${lib} ${lib}_UC )
        message(STATUS "simple_plugin: check ${lib}" )
        if( ${${lib}_UC} )
          message(STATUS "changing ${lib} to ${${${lib}_UC}}")
          list(APPEND cml_lib_list ${${${lib}_UC}})
        else()
          list(APPEND cml_lib_list ${lib})
        endif()
      endif( has_path )
    endforeach()
    target_link_libraries( ${CML_LIBRARY_NAME} ${cml_lib_list} )
  endif()
  if(COMMAND find_tbb_offloads)
    find_tbb_offloads(FOUND_VAR have_tbb_offload ${cet_src_list})
    if(have_tbb_offload)
      set_target_properties(${CML_LIBRARY_NAME} PROPERTIES LINK_FLAGS ${TBB_OFFLOAD_FLAG})
    endif()
  endif()
  message( STATUS "cet_make_library debug: CML_NO_INSTALL is ${CML_NO_INSTALL}")
  message( STATUS "cet_make_library debug: CML_WITH_STATIC_LIBRARY is ${CML_WITH_STATIC_LIBRARY}")
  if( CML_NO_INSTALL )
    message(STATUS "cet_make_library debug: ${CML_LIBRARY_NAME} will not be installed")
  else()
    _cet_check_lib_directory()
    cet_add_to_library_list( ${CML_LIBRARY_NAME})
    message(STATUS "cet_make_library: ${CML_LIBRARY_NAME} will be installed in ${${product}_lib_dir}")
    install( TARGETS  ${CML_LIBRARY_NAME} 
	     RUNTIME DESTINATION ${${product}_bin_dir}
	     LIBRARY DESTINATION ${${product}_lib_dir}
	     ARCHIVE DESTINATION ${${product}_lib_dir}
             )
  endif()
  if( CML_WITH_STATIC_LIBRARY )
    add_library( ${CML_LIBRARY_NAME}S STATIC ${cet_src_list} )
    if(CML_LIBRARIES)
       target_link_libraries( ${CML_LIBRARY_NAME}S ${cml_lib_list} )
    endif()
    set_target_properties( ${CML_LIBRARY_NAME}S PROPERTIES OUTPUT_NAME ${CML_LIBRARY_NAME} )
    set_target_properties( ${CML_LIBRARY_NAME}  PROPERTIES OUTPUT_NAME ${CML_LIBRARY_NAME} )
    set_target_properties( ${CML_LIBRARY_NAME}S PROPERTIES CLEAN_DIRECT_OUTPUT 1 )
    set_target_properties( ${CML_LIBRARY_NAME}  PROPERTIES CLEAN_DIRECT_OUTPUT 1 )
    if( CML_NO_INSTALL )
      message(STATUS "cet_make_library debug: ${CML_LIBRARY_NAME}S will not be installed")
    else()
      install( TARGETS  ${CML_LIBRARY_NAME}S 
	       RUNTIME DESTINATION ${${product}_bin_dir}
	       LIBRARY DESTINATION ${${product}_lib_dir}
	       ARCHIVE DESTINATION ${${product}_lib_dir}
               )
    endif()
  endif( CML_WITH_STATIC_LIBRARY )
endmacro( cet_make_library )
