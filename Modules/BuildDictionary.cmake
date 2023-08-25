#[================================================================[.rst:
BuildDictionary
===============

Module defining the function :command:`build_dictionary` to
generate a ROOT dictionary from a selection XML
(:file:`classes_def.xml`).

.. seealso::

   `ROOT Home Page <https://root.cern.ch>`_

   :module:`CetRootCint`
     Building a ROOT dictionary from a :file:`Linkdef.h` file.

#]================================================================]
include_guard()

cmake_minimum_required(VERSION 3.19...3.27 FATAL_ERROR)

include(CetPackagePath)
include(CetProcessLiblist)
include(CheckClassVersion)

set(_cet_build_dictionary_flags NO_CHECK_CLASS_VERSION NO_EXPORT
  NO_INSTALL NO_LIBRARY NO_RECURSIVE NOP RECURSIVE USE_PRODUCT_NAME
  USE_PROJECT_NAME)

set(_cet_build_dictionary_one_arg_options CLASSES_H CLASSES_DEF_XML
  DICT_NAME_VAR EXPORT_SET)

set(_cet_build_dictionary_list_options CCV_ENVIRONMENT COMPILE_FLAGS
    DICTIONARY_LIBRARIES REQUIRED_DICTIONARIES)

#[================================================================[.rst:
.. command:: build_dictionary

   Generate and build a ROOT dictionary module from a selection XML file
   (:file:`classes_def.xml`), optionally checking versions and checksums for
   selected classes.

   **Synopsis**
     .. code-block:: cmake

        build_dictionary([<name>] [<options>])

   **Options**
     ``CCV_ENVIRONMENT <var>=<val>...``
       List of environment settings to pass to
       :manual:`checkClassVersion(1)`.

     ``CLASSES_DEF_XML <filepath>``
       .. rst-class:: text-start
       The name and location of the selection XML file to be used
       (default: :variable:`${CMAKE_CURRENT_SOURCE_DIR}
       <cmake-ref-current:variable:CMAKE_CURRENT_SOURCE_DIR>`:file:`/classes_def.xml`).

     ``CLASSES_H <filepath>``
       .. rst-class:: text-start
       The name and location of the top-level C++ header file to be read
       (default: :variable:`${CMAKE_CURRENT_SOURCE_DIR}
       <cmake-ref-current:variable:CMAKE_CURRENT_SOURCE_DIR>`:file:`/classes.h`).

     ``COMPILE_FLAGS <flag>...``
       Extra compilation options.

     ``DICTIONARY_LIBRARIES <library-dependency>...``
       Libraries to which to link the dictionary plugin.

     ``DICT_NAME_VAR <var>``
       Variable in which to store the plugin name (useful when
       generated).

     ``EXPORT_SET <export-name>``
       Add the library to the ``<export-name>`` export set.

     ``NOP``
       Option / argument disambiguator; no other function.

     ``NO_CHECK_CLASS_VERSION``
       Do not run :manual:`checkClassVersion(1)` to verify class
       checksums and version numbers.

     ``NO_INSTALL``
       Do not install the generated plugin.

     ``NO_LIBRARY``
       Generate the C++ code, but do not compile it into a shared
       library (implies NO_CHECK_CLASS_VERSION).

     ``[NO_]RECURSIVE``
       Specify whether :manual:`checkClassVersion(1)` should check for
       the presence and validity of class dictionaries recursively
       (default determined by :command:`check_class_version`).

     ``REQUIRED_DICTIONARIES <dictionary-dependency>...``
       Specify dictionary dependencies required to be available for
       successful validation.

     ``USE_PRODUCT_NAME``
       .. deprecated:: 2.0 use ``USE_PACKAGE_NAME`` instead.

     ``USE_PACKAGE_NAME``
       The package name will be prepended to the pluign library name,
       separated by ``_``

   .. seealso:: :command:`cet_cmake_library`, :command:`check_class_version`

#]================================================================]
function(build_dictionary)
  set(build_dictionary_usage "USAGE: build_dictionary( [dictionary_name] [DICTIONARY_LIBRARIES <library list>] [COMPILE_FLAGS <flags>] [DICT_NAME_VAR <var>] [NO_INSTALL] )")
  cmake_parse_arguments(PARSE_ARGV 0 BD
    "${_cet_build_dictionary_flags}"
    "${_cet_build_dictionary_one_arg_options}"
    "${_cet_build_dictionary_list_options}")
  list(POP_FRONT BD_UNPARSED_ARGUMENTS dictname)
  if (BD_UNPARSED_ARGUMENTS)
	  message(FATAL_ERROR  "build_dictionary: too many arguments: \"${BD_UNPARSED_ARGUMENTS}\" from \"${ARGV}\" \n ${build_dictionary_usage}")
  endif()
  if (NOT TARGET ROOT::Core)
    find_package(ROOT 6.00.00 EXPORT QUIET REQUIRED COMPONENTS Core)
  endif()
  if (NOT dictname)
    cet_package_path(current_subdir)
    string(REPLACE "/" "_" dictname "${current_subdir}")
  endif()
  if (BD_USE_PRODUCT_NAME)
    string(PREPEND dictname "${CETMODULES_CURRENT_PROJECT_NAME}_")
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
  cet_process_liblist(dictionary_liblist ${dictname}_dict PRIVATE ${BD_DICTIONARY_LIBRARIES})
  set(cml_args)
  cet_passthrough(FLAG APPEND BD_NO_INSTALL cml_args)
  cet_passthrough(FLAG APPEND BD_NO_EXPORT cml_args)
  cet_passthrough(APPEND BD_EXPORT_SET cml_args)
  _generate_dictionary(${dictname}
    ${BD_CLASSES_DEF_XML} ${BD_CLASSES_H}
    AUX_OUTPUT_VAR AUX_OUTPUT)
  if (BD_COMPILE_FLAGS)
    set_source_files_properties(${dictname}_dict.cpp
      PROPERTIES COMPILE_FLAGS ${BD_COMPILE_FLAGS})
  endif()
  if (AUX_OUTPUT AND NOT BD_NO_INSTALL)
    install(FILES ${AUX_OUTPUT} DESTINATION ${${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY_DIR})
  endif()
  if (BD_NO_LIBRARY)
    return()
  endif()
  cet_make_library(LIBRARY_NAME ${dictname}_dict ${cml_args} SHARED SOURCE ${CMAKE_CURRENT_BINARY_DIR}/${dictname}_dict.cpp)
  if (NOT ROOT_VERSION GREATER_EQUAL 6.10.04 AND
      CMAKE_SYSTEM_NAME MATCHES "Darwin")
    # Header line and OS X lib name fixing only necessary for older ROOT6.
    add_custom_command(TARGET ${dictname}_dict POST_BUILD
      COMMAND perl -wapi.bak -e s&\\.dylib\\.so&.dylib&g ${AUX_OUTPUT}
      COMMAND rm -f ${AUX_OUTPUT}.bak
      COMMENT Fixing shared library reference in ${AUX_OUTPUT}
      VERBATIM)
  endif()
  if (TARGET ROOT::Core)
    list(APPEND dictionary_liblist PUBLIC ROOT::Core)
  else()
    list(APPEND dictionary_liblist PUBLIC ${ROOT_Core_LIBRARY})
  endif()
  target_link_libraries(${dictname}_dict ${dictionary_liblist})

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

function(_generate_dictionary dictname CLASSES_DEF_XML CLASSES_H)
  cmake_parse_arguments(PARSE_ARGV 2 GD "" "AUX_OUTPUT_VAR" "")
  set(generate_dictionary_usage "_generate_dictionary( [DICT_FUNCTIONS] [dictionary_name] )")
  # Add target-specific include directories and compile definitions,
  # accounting safely for generator expressions.
  set(tmp_defs "$<TARGET_PROPERTY:${dictname}_dict,COMPILE_DEFINITIONS>")
  set(ROOTCLING_DEFS "$<$<BOOL:${tmp_defs}>:-D$<JOIN:${tmp_defs},$<SEMICOLON>-D>>")
  set(tmp_includes "$<TARGET_PROPERTY:${dictname}_dict,INCLUDE_DIRECTORIES>")
  set(ROOTCLING_INCLUDES "$<$<BOOL:${tmp_includes}>:-I$<JOIN:${tmp_includes},$<SEMICOLON>-I>>")
  set(ROOTCLING_FLAGS
    --reflex
    -f
    ${CMAKE_CURRENT_BINARY_DIR}/${dictname}_dict.cpp
    --failOnWarnings
    --inlineInputHeader
    --noGlobalUsingStd
    --noIncludePaths
		-I${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}
    ${ROOTCLING_INCLUDES}
    ${ROOTCLING_DEFS}
  )
  if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/module.modulemap")
    list(APPEND ROOTCLING_FLAGS --cxxmodule -v)
    set(AUX_OUTPUT
      "$<TARGET_FILE_DIR:${dictname}_dict>/$<TARGET_FILE_BASE_NAME:${dictname}_dict>.pcm")
  else()
    set(AUX_OUTPUT
      "$<TARGET_FILE_DIR:${dictname}_dict>/$<TARGET_FILE_PREFIX:${dictname}_dict>$<TARGET_FILE_BASE_NAME:${dictname}_dict>.rootmap")
    list(APPEND ROOTCLING_FLAGS
      --rmf=${AUX_OUTPUT}
      --rml="$<TARGET_FILE_NAME:${dictname}_dict>"
    )
  endif()
  list(APPEND ROOTCLING_FLAGS
    -s "$<TARGET_LINKER_FILE:${dictname}_dict>")
  list(APPEND AUX_OUTPUT
      "$<TARGET_FILE_DIR:${dictname}_dict>/$<TARGET_FILE_PREFIX:${dictname}_dict>$<TARGET_FILE_BASE_NAME:${dictname}_dict>_rdict.pcm")
  if (GD_AUX_OUTPUT_VAR)
    set(${GD_AUX_OUTPUT_VAR} ${AUX_OUTPUT} PARENT_SCOPE)
  endif()
  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${dictname}_dict.cpp
    # Extra outputs commented out until custom_command OUTPUT supports
    # generator flags. See
    # https://gitlab.kitware.com/cmake/cmake/issues/12877.
    ${SOURCE_OUTPUT} # ${AUX_OUTPUT}
    COMMAND ROOT::rootcling
    ${ROOTCLING_FLAGS}
    ${CLASSES_H}
    ${CLASSES_DEF_XML}
    IMPLICIT_DEPENDS CXX ${CLASSES_H}
    DEPENDS ${CLASSES_DEF_XML}
    COMMAND_EXPAND_LISTS
    COMMENT "Generating dictionary files for target ${dictname}")
  # set variable for install_source
  set(cet_generated_code
    ${CMAKE_CURRENT_BINARY_DIR}/${dictname}_dict.cpp
    ${SOURCE_OUTPUT}
    PARENT_SCOPE)
endfunction()
