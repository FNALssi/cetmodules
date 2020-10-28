# macro for building ROOT dictionaries
#
# USAGE:
# build_dictionary( [<dictionary_name>]
#                   [COMPILE_FLAGS <flags>]
#                   [CLASSES_DEF_XML <filepath>]
#                   [CLASSES_H <filepath>]
#                   [DICT_NAME_VAR <var>]
#                   [DICTIONARY_LIBRARIES <library list>]
#                   [USE_PRODUCT_NAME]
#                   [NO_INSTALL]
#                   [DICT_FUNCTIONS]
#                   [NO_CHECK_CLASS_VERSION]
#                   [CCV_ENVIRONMENT <env_list>]
#                   [REQUIRED_DICTIONARIES <dictionary_list>]
#                   [RECURSIVE|NO_RECURSIVE]
#                   [UPDATE_IN_PLACE]
#                 )
#
# * <dictionary_name> defaults to a name based on the current source
# code subdirectory.
#
# * ${REFLEX} is always appended to the library list (even if it is
# empty).
#
# * Specify NO_INSTALL when building a dictionary for tests.
#
# * The default behavior is to generate a dictionary for data only. Use
# the DICT_FUNCTIONS option to reactivate the generation of dictionary
# entries for functions.
#
# * CLASSES_DEF_XML and CLASSES_H are optional and if not specified, we
# use classes_def.xml and classes.h respectively from the current source
# directory.
#
# * If DICT_NAME_VAR is specified, <var> will be set to contain the
# dictionary name.
#
# * check_class_version() is run by default. Use NO_CHECK_CLASS_VERSION
# to disable this behavior. CCV_ENVIRONMENT (as ENVIRONMENT),
# REQUIRED_DICTIONARIES, UPDATE_IN_PLACE, and {NO_,}RECURSIVE are passed
# through to check_class_version.
#
# * Any other macros or functions in this file are for internal use
# only.
#
########################################################################
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetPackagePath)
include(CetProcessLiblist)
include(CheckClassVersion)

set(GENREFLEX_FLAGS --fail_on_warnings
  $<$<VERSION_GREATER_EQUAL:${ROOT_VERSION},6.10.04>:--noIncludePaths>)

function( _generate_dictionary dictname CLASSES_DEF_XML CLASSES_H)
  cmake_parse_arguments(PARSE_ARGV 2 GD "" "ROOTMAP_OUTPUT;PCM_OUTPUT_VAR" "")
  set(generate_dictionary_usage "_generate_dictionary( [DICT_FUNCTIONS] [dictionary_name] )")
  get_directory_property( genpath INCLUDE_DIRECTORIES )
  foreach(inc IN LISTS genpath)
    set(GENREFLEX_INCLUDES ${GENREFLEX_INCLUDES} -I${inc})
  endforeach()
  # add any local compile definitions
  get_directory_property(compile_defs COMPILE_DEFINITIONS)
  foreach(def IN LISTS compile_defs)
    set(GENREFLEX_FLAGS ${GENREFLEX_FLAGS} -D${def})
  endforeach()
  list(APPEND GENREFLEX_FLAGS -l "$<TARGET_LINKER_FILE:${dictname}_dict>")
  if (GD_ROOTMAP_OUTPUT)
    list(APPEND GENREFLEX_FLAGS
      --rootmap-lib="$<TARGET_FILE_NAME:${dictname}_dict>"
      --rootmap=${GD_ROOTMAP_OUTPUT}
      )
  endif()
  set(PCM_OUTPUT
    "$<TARGET_FILE_DIR:${dictname}_dict>/$<TARGET_FILE_PREFIX:${dictname}_dict>$<TARGET_FILE_BASE_NAME:${dictname}_dict>_rdict.pcm")
  if (GD_PCM_OUTPUT_VAR)
    set(${GD_PCM_OUTPUT_VAR} ${PCM_OUTPUT} PARENT_SCOPE)
  endif()
  # FIXME Should be able to leverage CMake to do something more
  # straightforward than this!
  set(CXX_STD_FLAG "$<IF:$<BOOL:$<TARGET_PROPERTY:${dictname}_dict,CXX_EXTENSIONS>>,\
$<IF:$<EQUAL:11,$<TARGET_PROPERTY:${dictname}_dict,CXX_STANDARD>>,${CMAKE_CXX11_EXTENSION_COMPILE_OPTION},\
$<IF:$<EQUAL:14,$<TARGET_PROPERTY:${dictname}_dict,CXX_STANDARD>>,${CMAKE_CXX14_EXTENSION_COMPILE_OPTION},\
$<IF:$<EQUAL:17,$<TARGET_PROPERTY:${dictname}_dict,CXX_STANDARD>>,${CMAKE_CXX17_EXTENSION_COMPILE_OPTION},\
$<IF:$<EQUAL:20,$<TARGET_PROPERTY:${dictname}_dict,CXX_STANDARD>>,${CMAKE_CXX20_EXTENSION_COMPILE_OPTION},\
${CMAKE_CXX98_EXTENSION_COMPILE_OPTION}>>>>,\
$<IF:$<EQUAL:11,$<TARGET_PROPERTY:${dictname}_dict,CXX_STANDARD>>,${CMAKE_CXX11_STANDARD_COMPILE_OPTION},\
$<IF:$<EQUAL:14,$<TARGET_PROPERTY:${dictname}_dict,CXX_STANDARD>>,${CMAKE_CXX14_STANDARD_COMPILE_OPTION},\
$<IF:$<EQUAL:17,$<TARGET_PROPERTY:${dictname}_dict,CXX_STANDARD>>,${CMAKE_CXX17_STANDARD_COMPILE_OPTION},\
$<IF:$<EQUAL:20,$<TARGET_PROPERTY:${dictname}_dict,CXX_STANDARD>>,${CMAKE_CXX20_STANDARD_COMPILE_OPTION},\
${CMAKE_CXX98_STANDARD_COMPILE_OPTION}>>>>>\
")
  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${dictname}_dict.cpp
    # Extra outputs commented out until custom_command OUTPUT supports
    # generator flags. See
    # https://gitlab.kitware.com/cmake/cmake/issues/12877.
    ${SOURCE_OUTPUT} # ${GD_ROOTMAP_OUTPUT} ${PCM_OUTPUT}
    COMMAND ${ROOT_genreflex_CMD} ${CLASSES_H}
    -s ${CLASSES_DEF_XML}
		-I${PROJECT_SOURCE_DIR}
		${GENREFLEX_INCLUDES}
    ${CXX_STD_FLAG}
    ${GENREFLEX_FLAGS}
    -o ${dictname}_dict.cpp
    ${CLEANUP_COMMAND}
    IMPLICIT_DEPENDS CXX ${CLASSES_H}
    DEPENDS ${CLASSES_DEF_XML}
    COMMENT "Generating dictionary files for target ${dictname}")
  # set variable for install_source
  set(cet_generated_code
    ${CMAKE_CURRENT_BINARY_DIR}/${dictname}_dict.cpp
    ${SOURCE_OUTPUT}
    PARENT_SCOPE)
endfunction()

set(_cet_build_dictionary_flags
  NO_CHECK_CLASS_VERSION NO_INSTALL NO_RECURSIVE NOP
  RECURSIVE USE_PRODUCT_NAME USE_PROJECT_NAME)

set(_cet_build_dictionary_one_arg_options
  CLASSES_H CLASSES_DEF_XML DICT_NAME_VAR EXPORT)

set(_cet_build_dictionary_list_options
    CCV_ENVIRONMENT COMPILE_FLAGS DICTIONARY_LIBRARIES REQUIRED_DICTIONARIES)

function(build_dictionary)
  set(build_dictionary_usage "USAGE: build_dictionary( [dictionary_name] [DICTIONARY_LIBRARIES <library list>] [COMPILE_FLAGS <flags>] [DICT_NAME_VAR <var>] [NO_INSTALL] )")
  cmake_parse_arguments(PARSE_ARGV 0 BD
    "${_cet_build_dictionary_flags}"
    "${_cet_build_dictionary_one_arg_options}"
    "${_cet_build_dictionary_list_options}")
  list(POP_FRONT dictname)
  if (BD_UNPARSED_ARGUMENTS)
	  message(FATAL_ERROR  "build_dictionary: too many arguments. ${ARGV} \n ${build_dictionary_usage}")
  endif()
  find_package(ROOT 6.00.00 QUIET REQUIRED COMPONENTS Core)
  if (NOT dictname)
    cet_package_path(current_subdir)
    string(REPLACE "/" "_" dictname "${current_subdir}")
  endif()
  if (BD_USE_PRODUCT_NAME)
    string(PREPEND dictname "${PROJECT_NAME}_")
  endif()
  if (BD_DICT_NAME_VAR)
    set(${BD_DICT_NAME_VAR} ${dictname} PARENT_SCOPE)
  endif()
  if (NOT BD_CLASSES_DEF_XML)
    set(BD_CLASSES_DEF_XML ${CMAKE_CURRENT_SOURCE_DIR}/classes_def.xml)
  endif()
  if (NOT BD_CLASSES_H)
    set(BD_CLASSES_H ${CMAKE_CURRENT_SOURCE_DIR}/classes.h)
  endif()
  cet_process_liblist(dictionary_liblist ${BD_DICTIONARY_LIBRARIES})
  list(APPEND dictionary_liblist )
  set(cml_args)
  cet_passthrough(FLAG APPEND BD_NO_INSTALL cml_args)
  cet_passthrough(APPEND BD_EXPORT cml_args)
  cet_make_library(LIBRARY_NAME ${dictname}_dict ${cml_args} SHARED SOURCE ${CMAKE_CURRENT_BINARY_DIR}/${dictname}_dict.cpp)
  set(ROOTMAP_OUTPUT
    "$<TARGET_FILE_DIR:${dictname}_dict>/$<TARGET_FILE_PREFIX:${dictname}_dict>$<TARGET_FILE_BASE_NAME:${dictname}_dict>.rootmap")
  cet_find_package(ROOT PUBLIC QUIET COMPONENTS Core REQUIRED)
  _generate_dictionary(${dictname}
    ${BD_CLASSES_DEF_XML} ${BD_CLASSES_H}
    ROOTMAP_OUTPUT "${ROOTMAP_OUTPUT}"
    PCM_OUTPUT_VAR PCM_OUTPUT)
  if (NOT ROOT_VERSION GREATER_EQUAL 6.10.04 AND
      CMAKE_SYSTEM_NAME MATCHES "Darwin")
    # Header line and OS X lib name fixing only necessary for older ROOT6.
    add_custom_command(TARGET ${dictname}_dict POST_BUILD
      COMMAND perl -wapi.bak -e s&\\.dylib\\.so&.dylib&g ${ROOTMAP_OUTPUT}
      COMMAND rm -f ${ROOTMAP_OUTPUT}.bak
      COMMENT Fixing shared library reference in ${ROOTMAP_OUTPUT}
      VERBATIM)
  endif()
  if (BD_COMPILE_FLAGS)
    set_target_properties(${dictname}_dict
      PROPERTIES COMPILE_FLAGS ${BD_COMPILE_FLAGS})
  endif()
  if (TARGET ROOT::Core)
    list(APPEND dictionary_liblist PUBLIC ROOT::Core)
  else()
    list(APPEND dictionary_liblist PUBLIC ${ROOT_Core_LIBRARY})
  endif()
  target_link_libraries(${dictname}_dict ${dictionary_liblist})

  if (NOT BD_NO_INSTALL)
    install(FILES ${ROOTMAP_OUTPUT} DESTINATION ${${PROJECT_NAME}_LIBRARY_DIR})
    if (PCM_OUTPUT)
      install(FILES ${PCM_OUTPUT} DESTINATION ${${PROJECT_NAME}_LIBRARY_DIR})
    endif()
  endif()
  if (NOT TARGET BuildDictionary_AllDicts)
    add_custom_target(BuildDictionary_AllDicts)
  endif()
  add_dependencies(BuildDictionary_AllDicts ${dictname}_dict)
  if (BD_NO_CHECK_CLASS_VERSION OR NOT DEFINED CCV_DEFAULT_RECURSIVE)
    # Turned off manually, or we're using or building an older art.
    if (BD_REQUIRED_DICTIONARIES OR
        BD_RECURSIVE OR BD_NO_RECURSIVE OR BD_CCV_ENVIRONMENT)
      message(WARNING "BuildDictionary: NO_CHECK_CLASS_VERSION is set: CCV_ENVIRONMENT, REQUIRED_DICTIONARIES, RECURSIVE AND NO_RECURSIVE are ignored.")
    endif()
  else ()
    set(BD_CCV_ARGS)
    cet_passthrough(APPEND BD_REQUIRED_DICTIONARIES BD_CCV_ARGS)
    cet_passthrough(APPEND BD_CLASSES_DEF_XML BD_CCV_ARGS)
    cet_passthrough(FLAG APPEND BD_RECURSIVE BD_CCV_ARGS)
    cet_passthrough(FLAG APPEND BD_NO_RECURSIVE BD_CCV_ARGS)
    cet_passthrough(APPEND KEYWORD ENVIRONMENT BD_CCV_ENVIRONMENT BD_CCV_ARGS)
    check_class_version(${BD_LIBRARIES} UPDATE_IN_PLACE ${BD_CCV_ARGS})
  endif()
endfunction()

CMAKE_POLICY(POP)
