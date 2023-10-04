#[================================================================[.rst:
X
-
#]================================================================]
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
include_guard()

cmake_minimum_required(VERSION 3.18.2...3.27 FATAL_ERROR)

# Note that the required minimum version here is checked against
# "Implementation-Version," a vendor-supplied key in the
# META-INF/MANIFEST.MF file inside the JAR file, which is just a zip
# file. In the case of Smc, this version is 6.0.1 for at least Smc
# versions 6.1.0 and 6.6.0 that we know of.
find_package(Smc 6.0.1 REQUIRED EXPORT)

function(process_smc TARGET_OR_VAR)
  cmake_parse_arguments (PARSE_ARGV 1 PSMC "NO_INSTALL" "OUTPUT_DIR" "")
  if (NOT PSMC_OUTPUT_DIR)
    set(PSMC_OUTPUT_DIR .)
  endif()
  list(TRANSFORM PSMC_UNPARSED_ARGUMENTS REPLACE "^(.*/)?(.*).sm$" "\\2_sm.cpp"
    OUTPUT_VARIABLE SMC_CPP_OUTPUTS)
  list(TRANSFORM PSMC_UNPARSED_ARGUMENTS REPLACE "^(.*/)?(.*).sm$" "\\2_sm.h"
    OUTPUT_VARIABLE SMC_H_OUTPUTS)
  list(TRANSFORM PSMC_UNPARSED_ARGUMENTS REPLACE "^(.*/)?(.*).sm$" "\\2_sm.dot"
    OUTPUT_VARIABLE SMC_DOT_OUTPUTS)
  set(smc_cmd java -jar "$<TARGET_FILE:Smc::Smc>")
  cet_package_path(pkgpath PATH "${PSMC_OUTPUT_DIR}" BINARY)
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${PSMC_OUTPUT_DIR}")
  foreach (source cpp_out h_out dot_out IN ZIP_LISTS
      PSMC_UNPARSED_ARGUMENTS SMC_CPP_OUTPUTS SMC_H_OUTPUTS SMC_DOT_OUTPUTS)
    cmake_path(ABSOLUTE_PATH source OUTPUT_VARIABLE abs_source)
    add_custom_command(OUTPUT "${PSMC_OUTPUT_DIR}/${cpp_out}"
      "${PSMC_OUTPUT_DIR}/${h_out}"
      COMMAND pwd
      COMMAND ${smc_cmd} -d "${pkgpath}" -c++ "${abs_source}"
      COMMAND perl -wapi~ -e
      "s&(#\\s*include\\s+)<statemap\\.h>&\${1}\"${pkgpath}/statemap.h\"&"
      "${pkgpath}/${h_out}"
      WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
      VERBATIM
      COMMENT "Generating C++ files from state machine ${source}"
      MAIN_DEPENDENCY "${source}"
      DEPENDS Smc::Smc)
    add_custom_command(OUTPUT "${PSMC_OUTPUT_DIR}/${dot_out}"
      COMMAND ${smc_cmd} -d "${PSMC_OUTPUT_DIR}" -graph -glevel 2 "${abs_source}"
      COMMENT "Generating Graphviz output from state machine ${source}"
      MAIN_DEPENDENCY "${source}"
      DEPENDS Smc::Smc)
    string(MAKE_C_IDENTIFIER
      "${CETMODULES_CURRENT_PROJECT}/${pkgpath}/${dot_out}"
      dot_target)
    add_custom_target(${dot_target} ALL
      DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/${PSMC_OUTPUT_DIR}/${dot_out}")
  endforeach()
  configure_file("${Smc_statemap_h}" "${PSMC_OUTPUT_DIR}/" COPYONLY)
  if (NOT PSMC_NO_INSTALL)
    list(APPEND SMC_H_OUTPUTS "statemap.h")
    list(TRANSFORM SMC_H_OUTPUTS PREPEND "${PROJECT_BINARY_DIR}/${pkgpath}/")
    list(TRANSFORM SMC_CPP_OUTPUTS PREPEND "${PROJECT_BINARY_DIR}/${pkgpath}/")
    install_headers(LIST ${SMC_H_OUTPUTS})
    install_source(LIST ${SMC_H_OUTPUTS} ${SMC_CPP_OUTPUTS})
  endif()
  set_source_files_properties(${SMC_CPP_OUTPUTS}
    PROPERTIES COMPILE_FLAGS "-Wno-unused-parameter"
  )
  if (TARGET ${TARGET_OR_VAR})
    target_sources(${TARGET_OR_VAR} PRIVATE ${SMC_CPP_OUTPUTS})
  else()
    warn_deprecated("process_smc(<var>)" NEW "process_smc(<library-target>)")
    set(${TARGET_OR_VAR} ${SMC_CPP_OUTPUTS} PARENT_SCOPE)
  endif()
endfunction()
