#
# cet_rootcint(<output_name> [NO_INSTALL])
# runs rootcint against files in CMAKE_CURRENT_SOURCE_DIR and puts the result in CMAKE_CURRENT_BINARY_DIR

include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetPackagePath)

set(_RC_PROG "$<IF:$<TARGET_EXISTS:ROOT::rootcling>,ROOT::rootcling,${ROOT_rootcling_CMD}>")
set(_RC_FLAGS "$<$<VERSION_GREATER_EQUAL:${ROOT_VERSION},6.10.04>:-noIncludePaths>")

function(cet_rootcint OUTPUT_NAME)
  set(cet_rootcint_usage "USAGE: cet_rootcint(<package name> [NO_INSTALL])")
  cmake_parse_arguments(PARSE_ARGV 1 RC "NO_INSTALL;VERSION" "EXPORT;LIB_TARGET" "")
  if (RC_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR  "cet_rootcint: Incorrect arguments. ${ARGV} \n ${cet_rootcint_usage}")
  endif()
  # generate the list of headers to be parsed by cint
  cet_package_path(curdir)
  file(GLOB CINT_CXX *.cxx)
  list(TRANSFORM CINT_CXX REPLACE "\\.cxx$" ".h"
    OUTPUT_VARIABLE CINT_DEPENDS)
  list(TRANSFORM CINT_CXX REPLACE "^.*/(.*)\\.cxx$" "${curdir}/\\1.h"
    OUTPUT_VARIABLE CINT_HEADER_LIST)
  if (NOT RC_LIB_TARGET)
    if (TARGET ${OUTPUT_NAME}_dict)
      set(RC_LIB_TARGET ${OUTPUT_NAME}_dict)
    elseif (TARGET ${OUTPUT_NAME})
      set(RC_LIB_TARGET ${OUTPUT_NAME})
    endif()
  endif()
  if (RC_LIB_TARGET)
    set(lib_path "$<TARGET_PROPERTY:${RC_LIB_TARGET},LIBRARY_OUTPUT_DIRECTORY>")
    set(CINT_INCS "$<TARGET_PROPERTY:${RC_LIB_TARGET},INCLUDE_DIRECTORIES>")
  else()
    set(lib_path "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
    get_property(CINT_INCS DIRECTORY PROPERTY INCLUDE_DIRECTORIES)
    list(REMOVE_DUPLICATES CINT_INCS)
  endif()
  if (CINT_INCS)
    set(CINT_INCS "-I$<JOIN:${CINT_INCS},$<SEMICOLON>-I>")
  endif()
  set(RC_RMF "${lib_path}/${CMAKE_SHARED_LIBRARY_PREFIX}${OUTPUT_NAME}.rootmap")
  set(RC_PCM "${lib_path}/${CMAKE_SHARED_LIBRARY_PREFIX}${OUTPUT_NAME}_rdict.pcm")
  set(RC_OUTPUT_LIBRARY
    "${lib_path}/${CMAKE_SHARED_LIBRARY_PREFIX}${OUTPUT_NAME}${CMAKE_SHARED_LIBRARY_SUFFIX}")
  get_filename_component(RC_RML ${RC_OUTPUT_LIBRARY} NAME)
  set(RC_FLAGS ${_RC_FLAGS}
    -s "${RC_OUTPUT_LIBRARY}"
    -rml "${RC_RML}"
    -rmf "${RC_RMF}"
   )
  if (NOT ROOT_VERSION GREATER_EQUAL 6.10.04 AND
      CMAKE_SYSTEM_NAME MATCHES "Darwin")
    # Header line and OS X lib name fixing only necessary for older ROOT6.
    set(RC_EXTRA
      COMMAND perl -wapi.bak -e "s&\\.dylib\\.so&.dylib&g$<SEMICOLON> s&^(header\\s+)([^/]+)$&\${1}${curdir}/\${2}&" "${RC_RMF}"
      COMMAND rm -f "${RC_RMF}.bak")
  endif()
  add_custom_command(
    # Extra outputs commented out until custom_command OUTPUT supports
    # generator flags.
    OUTPUT ${OUTPUT_NAME}Cint.cc # ${RC_PCM} ${RC_RMF}
    COMMAND ${_RC_PROG} -f ${CMAKE_CURRENT_BINARY_DIR}/${OUTPUT_NAME}Cint.cc
    ${RC_FLAGS}
		-I${PROJECT_SOURCE_DIR} "${CINT_INCS}"
    -I${ROOTSYS}/include
		-DUSE_ROOT
		${CINT_HEADER_LIST} LinkDef.h
    ${RC_EXTRA}
    DEPENDS ${CINT_DEPENDS} LinkDef.h
    IMPLICIT_DEPENDS ${CINT_DEPENDS} LinkDef.h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Generating ROOTCint dictionary in ${curdir}"
    COMMAND_EXPAND_LISTS
   )
  # set variable for install_source
  if (NOT RC_NO_INSTALL)
    if (RC_PCM)
      install(FILES ${RC_PCM} DESTINATION ${${PROJECT_NAME}_LIBRARY_DIR})
    endif()
    if (RC_RMF)
      install(FILES ${RC_RMF} DESTINATION ${${PROJECT_NAME}_LIBRARY_DIR})
    endif()
  endif()
  #message(STATUS "cet_rootcint debug: generated code list ${cet_generated_code}")
endfunction()

cmake_policy(POP)
