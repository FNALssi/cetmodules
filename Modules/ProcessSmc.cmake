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
# Avoid unwanted repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

# Note that the required minimum version here is checked against
# "Implementation-Version," a vendor-supplied key in the
# META-INF/MANIFEST.MF file inside the JAR file, which is just a zip
# file. In the case of Smc, this version is 6.0.1 for at least Smc
# versions 6.1.0 and 6.6.0 that we know of.
cet_find_package(Smc 6.0.1 REQUIRED PUBLIC)

function(process_smc TARGET_OR_VAR)
  cmake_parse_arguments (PARSE_ARGV 1 PSMC "NO_INSTALL" "" "")
  list(TRANSFORM PSMC_UNPARSED_ARGUMENTS REPLACE "^(.*).sm$" "\\1_sm.cpp"
    OUTPUT_VARIABLE SMC_CPP_OUTPUTS)
  list(TRANSFORM PSMC_UNPARSED_ARGUMENTS REPLACE "^(.*).sm$" "\\1_sm.h"
    OUTPUT_VARIABLE SMC_H_OUTPUTS)
  list(TRANSFORM PSMC_UNPARSED_ARGUMENTS REPLACE "^(.*).sm$" "\\1_sm.dot"
    OUTPUT_VARIABLE SMC_DOT_OUTPUTS)
  set(smc_cmd java -jar "$<TARGET_FILE:Smc::Smc>"
    -d "${CMAKE_CURRENT_BINARY_DIR}")
  foreach (source cpp_out h_out dot_out IN ZIP_LISTS
      PSMC_UNPARSED_ARGUMENTS SMC_CPP_OUTPUTS SMC_H_OUTPUTS SMC_DOT_OUTPUTS)
    add_custom_command(OUTPUT "${cpp_out}" "${h_out}" "${dot_out}"
      COMMAND ${smc_cmd} -graph -glevel 2 "${CMAKE_CURRENT_SOURCE_DIR}/${source}" &&
      ${smc_cmd} -d "${CMAKE_CURRENT_BINARY_DIR}" -c++ "${CMAKE_CURRENT_SOURCE_DIR}/${source}" &&
      perl -wapi\\~ -e "'s&\(\#\\s*include\\s+\"\)\\Q${CETMODULES_CURRENT_PROJECT_BINARY_DIR}/\\E&$$1&'"
      "${cpp_out}"
      MAIN_DEPENDENCY "${source}"
      DEPENDS Smc::Smc)
  endforeach()
  if (NOT PSMC_NO_INSTALL)
    install_headers(LIST ${CMAKE_CURRENT_BINARY_DIR}/${SMC_H_OUTPUTS})
    install_source(LIST ${CMAKE_CURRENT_BINARY_DIR}/${SMC_H_OUTPUTS}
      ${CMAKE_CURRENT_BINARY_DIR}/${SMC_CPP_OUTPUTS})
  endif()
  set_source_files_properties(${SMC_CPP_OUTPUTS}
    PROPERTIES COMPILE_FLAGS "-Wno-unused-parameter"
    INCLUDE_DIRECTORIES
    $<TARGET_PROPERTY:Smc::Smc,INTERFACE_INCLUDE_DIRECTORIES>
    INTERFACE_INCLUDE_DIRECTORIES
    $<TARGET_PROPERTY:Smc::Smc,INTERFACE_INCLUDE_DIRECTORIES>)
  if (TARGET TARGET_OR_VAR)
    add_target_sources(${TARGET_OR_VAR} PRIVATE ${SMC_CPP_OUTPUTS}
      PUBLIC ${SMC_DOT_OUTPUTS})
    target_link_libraries(${TARGET_OR_VAR} Smc::Smc)
  else()
    warn_deprecated("process_smc(<var>)" NEW "process_smc(<library-target>)")
    set(${TARGET_OR_VAR} ${SMC_CPP_OUTPUTS} PARENT_SCOPE)
  endif()
endfunction()

cmake_policy(POP)
