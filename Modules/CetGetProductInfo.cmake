# start by finding  report_product_info
find_program(GET_PRODUCT_INFO report_product_info "${cetmods_BINDIR}")
if ( NOT GET_PRODUCT_INFO )
  MESSAGE(FATAL_ERROR "CetGetProductInfo.cmake: could not find report_product_info in ${cetmods_BINDIR}")
endif ( NOT GET_PRODUCT_INFO )

function(cet_get_product_info_item ITEM OUTPUT_VAR)
  if (NOT PROJECT_BINARY_DIR)
    message(FATAL_ERROR "cet_get_product_info_item: PROJECT_BINARY_DIR is not defined")
  endif()
  execute_process(COMMAND ${GET_PRODUCT_INFO}
    ${PROJECT_BINARY_DIR}
    ${ITEM}
    OUTPUT_VARIABLE output
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE ec
    ERROR_VARIABLE report_product_info_error
    ERROR_STRIP_TRAILING_WHITESPACE
    )
  if( report_product_info_error )
    message(FATAL_ERROR "cet_get_product_info_item: ${report_product_info_error}")
  endif()
  set(${OUTPUT_VAR} ${output} PARENT_SCOPE)
  if(ARGV2)
    set(${ARGV2} ${ec} PARENT_SCOPE)
  endif()
endfunction()
