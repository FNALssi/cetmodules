# internal function

# This function presumes that glob has been used to generate the list
# _cet_exclude_from_list( OUTPUT_VAR
#                         LIST <input file list>
#                         EXCLUDES <files to exclude> )

function (_cet_exclude_from_list OUTPUT_VAR )
  cmake_parse_arguments( XL "" "" "LIST;EXCLUDES" ${ARGN})
  #message(STATUS "_cet_exclude_from_list: prepend ${CMAKE_CURRENT_SOURCE_DIR} to ${XL_EXCLUDES}")
  set( fileList "" )
  foreach( myfile ${XL_EXCLUDES} )
      get_filename_component( mydir "${myfile}" DIRECTORY )
      if( IS_ABSOLUTE "${mydir}" )
           list(APPEND fileList "${myfile}")
      else()
          list(APPEND fileList "${CMAKE_CURRENT_SOURCE_DIR}/${myfile}")
      endif()
  endforeach()
  LIST( REMOVE_ITEM XL_LIST ${fileList} )
  #message(STATUS "_cet_exclude_from_list returns ${XL_LIST}" )
  set (${OUTPUT_VAR} "${XL_LIST}" PARENT_SCOPE)
  #message(STATUS "_cet_exclude_from_list output in ${OUTPUT_VAR}" )
endfunction()
