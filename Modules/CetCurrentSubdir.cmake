# internal function

function (_cet_current_subdir OUTPUT_VAR)

  if( PACKAGE_TOP_DIRECTORY )
    STRING( REGEX REPLACE "^${PACKAGE_TOP_DIRECTORY}(.*)" "\\1" OUTPUT_SUBDIR "${CMAKE_CURRENT_SOURCE_DIR}" )
  else()
    STRING( REGEX REPLACE "^${CMAKE_SOURCE_DIR}(.*)" "\\1" OUTPUT_SUBDIR "${CMAKE_CURRENT_SOURCE_DIR}" )
  endif()
  ##message(STATUS "_cet_current_subdir found ${OUTPUT_SUBDIR}" )
  set (${OUTPUT_VAR} "${OUTPUT_SUBDIR}" PARENT_SCOPE)

endfunction()
