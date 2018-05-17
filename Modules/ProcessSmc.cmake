########################################################################
# process_smc
#
# Process state machine files (.sm) into C++ source for inclusion in a
# library.
#
# Usage:
#
# process_smc(LIB_SOURCES_VAR [NO_INSTALL] <.sm files>)
#
####################################
# Notes
#
# The LIB_SOURCES_VAR argument should be the name of a variable whose
# contents after calling will be the list of C++ source files generated
# by the state machine compiler.
#
########################################################################

include(CMakeParseArguments)

find_ups_product(smc_compiler v6_1_0)
include_directories("$ENV{SMC_HOME}/lib/C++")

function(process_smc LIB_SOURCES_VAR)
  cmake_parse_arguments ( PSMC "NO_INSTALL" "" "" ${ARGN})
  foreach(source ${PSMC_UNPARSED_ARGUMENTS})
    string(REPLACE ".sm" "_sm.cpp" SMC_CPP_OUTPUT ${source})
    string(REPLACE ".sm" "_sm.h"   SMC_H_OUTPUT   ${source})
    string(REPLACE ".sm" "_sm.dot" SMC_DOT_OUTPUT ${source})
    list(APPEND TMP_SOURCES ${SMC_CPP_OUTPUT})
    add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${SMC_H_OUTPUT}
      ${CMAKE_CURRENT_BINARY_DIR}/${SMC_CPP_OUTPUT}
      ${CMAKE_CURRENT_BINARY_DIR}/${SMC_DOT_OUTPUT}
      COMMAND java -jar $ENV{SMC_HOME}/bin/Smc.jar -d ${CMAKE_CURRENT_BINARY_DIR} -graph -glevel 2 ${CMAKE_CURRENT_SOURCE_DIR}/${source}
      COMMAND java -jar $ENV{SMC_HOME}/bin/Smc.jar -d ${CMAKE_CURRENT_BINARY_DIR} -c++ ${CMAKE_CURRENT_SOURCE_DIR}/${source}
      COMMAND perl -wapi\\~ -e 's&\(\#\\s*include\\s+\"\)\\Q${CMAKE_BINARY_DIR}/\\E&$$1&' ${CMAKE_CURRENT_BINARY_DIR}/${SMC_CPP_OUTPUT}
      DEPENDS ${source}
      )
    if (NOT ${PSMC_NO_INSTALL})
      install_headers(LIST ${CMAKE_CURRENT_BINARY_DIR}/${SMC_H_OUTPUT})
      install_source(LIST ${CMAKE_CURRENT_BINARY_DIR}/${SMC_H_OUTPUT}
        ${CMAKE_CURRENT_BINARY_DIR}/${SMC_CPP_OUTPUT}
        )
    endif()
  endforeach()
  set_source_files_properties(${TMP_SOURCES}
    PROPERTIES COMPILE_FLAGS "-Wno-unused-parameter" )
  set(${LIB_SOURCES_VAR} ${TMP_SOURCES} PARENT_SCOPE)
endfunction()
