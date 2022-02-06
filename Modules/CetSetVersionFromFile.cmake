include_guard()

cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

function(cet_set_version_from_file)
  cmake_parse_arguments(PARSE_ARGV 0 CSVF
    "EXTENDED_VERSION_SEMANTICS;NOP" "PROJECT;VERSION_FILE" ""
    )
  if (NOT CSVF_PROJECT)
    set(CSVF_PROJECT ${PROJECT_NAME})
  endif()
  if (NOT CSVF_VERSION_FILE)
    set(CSVF_VERSION_FILE "${${CSVF_PROJECT}_SOURCE_DIR}/VERSION")
  endif()
  file(READ "${CSVF_VERSION_FILE}" version_string)
  string(STRIP "${version_string}" version_string)
  set(${CSVF_PROJECT}_CMAKE_PROJECT_VERSION_STRING "${version_string}" PARENT_SCOPE)
  if (CSVF_EXTENDED_VERSION_SEMANTICS)
    set(${PROJECT_NAME}_EXTENDED_VERSION_SEMANTICS TRUE PARENT_SCOPE)
  endif()
endfunction()
