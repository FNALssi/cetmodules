find_program(SPHINX-BUILD_EXECUTABLE sphinx-build DOC "Location of sphinx-build documentation compiler")
mark_as_advanced(SPHINX-BUILD_EXECUTABLE)
if (SPHINX-BUILD_EXECUTABLE)
  if (NOT TARGET sphinx-doc::sphinx-build)
    add_executable(sphinx-doc::sphinx-build IMPORTED)
    set_target_properties(sphinx-doc::sphinx-build PROPERTIES
      IMPORTED_LOCATION "${SPHINX-BUILD_EXECUTABLE}")
  endif()
  message(VERBOSE "SPHINX-BUILD_EXECUTABLE=${SPHINX-BUILD_EXECUTABLE}")

  find_package(Python3 COMPONENTS Interpreter REQUIRED)

  execute_process(COMMAND "${SPHINX-BUILD_EXECUTABLE}" --version
    ERROR_QUIET
    OUTPUT_VARIABLE sphinx-doc_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REGEX REPLACE "^[^ 	]+[ 	]+" ""
    sphinx-doc_VERSION "${sphinx-doc_VERSION}")
  message(VERBOSE "Found sphinx-doc_VERSION=${sphinx-doc_VERSION}")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(sphinx-doc
  VERSION_VAR sphinx-doc_VERSION
  REQUIRED_VARS SPHINX-BUILD_EXECUTABLE)
