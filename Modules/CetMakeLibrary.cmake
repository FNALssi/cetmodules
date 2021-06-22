#[================================================================[.rst:
X
=
#]================================================================]
# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetInstalledPath)
include(CetCMakeUtils)
include(CetRegexEscape)

set(_cet_make_library_usage "")

function(cet_make_library)
  # Two-phase parsing to avoid confusion with e.g. INTERFACE in
  # LIBRARIES list.
  cmake_parse_arguments(PARSE_ARGV 0 CML
    "BASENAME_ONLY;EXCLUDE_FROM_ALL;HEADERS_TARGET;MODULE;NO_EXPORT;NO_INSTALL;NO_OBJECT;NO_SOURCE;NOP;OBJECT;SHARED;STATIC;USE_BOOST_UNIT;USE_PROJECT_NAME;VERSION;WITH_STATIC_LIBRARY"
    "EXPORT_SET;INSTALLED_PATH_BASE;LIBRARY_NAME;LIBRARY_NAME_VAR;SOVERSION;TARGET_NAME"
    "ALIAS;LIBRARIES;LOCAL_INCLUDE_DIRS;SOURCE;STRIP_LIBS")
  cmake_parse_arguments(CML2
    "INTERFACE" "" "" ${CML_UNPARSED_ARGUMENTS})
  ##################
  # Argument verification.
  if (NOT (CML_NO_SOURCE OR CML_SOURCE OR
        "SOURCE" IN_LIST CML_KEYWORDS_MISSING_VALUES))
    message(FATAL_ERROR "SOURCE or NO_SOURCE is required")
  endif()
  # Target alias namespace.
  cet_register_export_set(SET_NAME ${CML_EXPORT_SET} SET_VAR CML_EXPORT_SET
    NAMESPACE_VAR namespace)
  ##################
  # Generate useful library/target names.
  set(libname_bits "${CML_LIBRARY_NAME}")
  set(targetname_bits)
  cet_package_path(prefix SOURCE)
  if (prefix STREQUAL ".")
    unset(prefix)
  else()
    get_filename_component(basename "${prefix}" NAME)
  endif()
  if (prefix AND NOT libname_bits)
    if (CML_BASENAME_ONLY)
      set(libname_bits "${basename}")
    else()
      set(libname_bits "${prefix}")
    endif()
  endif()
  if (CML_USE_PROJECT_NAME)
    list(PREPEND libname_bits "${CETMODULES_CURRENT_PROJECT_NAME}")
  elseif (NOT libname_bits)
    message(FATAL_ERROR "cet_make_library() invoked from ${CETMODULES_CURRENT_PROJECT_NAME} top directory: \
LIBRARY_NAME or USE_PROJECT_NAME options required\
")
  endif()
  if (CML_TARGET_NAME STREQUAL "BASENAME")
    set(targetname_bits ${basename})
  elseif (NOT CML_TARGET_NAME)
    set(targetname_bits "${libname_bits}")
  endif()
  # Sanitize.
  string(REGEX REPLACE "[/:;_]+" "_" CML_LIBRARY_NAME "${libname_bits}")
  string(REGEX REPLACE "[/:;_]+" "_" CML_TARGET_NAME "${targetname_bits}")
  cet_regex_escape("${namespace}" e_namespace)
  if (CML_TARGET_NAME MATCHES "^${e_namespace}_(.*)$")
    set(CML_EXPORT_NAME "${CMAKE_MATCH_1}")
  else()
    unset(CML_EXPORT_NAME)
  endif()
  ##################
  # Make sure we have access to Boost's unit test library if we need it.
  if (CML_USE_BOOST_UNIT)
    cet_find_package(Boost PRIVATE QUIET COMPONENTS unit_test_framework REQUIRED)
  endif()
  ##################
  # Handle choices for library types.
  if (CML2_INTERFACE)
    set(link_scope INTERFACE)
    set(include_scope INTERFACE)
    set(lib_scope INTERFACE)
  else()
    set(link_scope PRIVATE)
    set(include_scope PUBLIC)
    set(lib_scope PUBLIC)
  endif()
  # Get appropriate list of libraries to which to link.
  cet_process_liblist(liblist ${lib_scope} ${CML_LIBRARIES})
  if (CETMODULES_MODULE_PLUGINS)
    set(CML_MODULE)
  endif()
  cet_passthrough(FLAG IN_PLACE CML2_INTERFACE)
  cet_passthrough(FLAG IN_PLACE CML_MODULE)
  cet_passthrough(FLAG IN_PLACE CML_OBJECT)
  cet_passthrough(FLAG IN_PLACE CML_SHARED)
  cet_passthrough(FLAG IN_PLACE CML_STATIC)
  # The order is important here, determining which library gets to be
  # the one without the suffix.
  set(lib_types
    ${CML_OBJECT}
    ${CML2_INTERFACE}
    ${CML_SHARED}
    ${CML_MODULE}
    ${CML_STATIC}
    )
  if (NOT lib_types)
    if (BUILD_SHARED_LIBS)
      list(APPEND lib_types SHARED)
    endif()
    if (BUILD_STATIC_LIBS OR CML_WITH_STATIC_LIBRARY)
      list(APPEND lib_types STATIC)
    endif()
  endif()
  list(LENGTH lib_types num_libtypes)
  if (CML_INSTALLED_PATH_BASE AND NOT CML2_INTERFACE)
    message(FATAL_ERROR "INSTALLED_PATH_BASE valid only for INTERFACE library types")
  elseif (CML2_INTERFACE AND num_libtypes GREATER 1)
    message(FATAL_ERROR "INTERFACE library is incompatible with any other library type: build separately")
  elseif (NOT CML_NO_OBJECT AND
      (num_libtypes GREATER 2 OR
        (CML_STATIC AND NOT USE_BOOST_UNIT AND (CML_MODULE OR CML_SHARED))))
    set(CML_OBJECT TRUE)
    list(PREPEND lib_types ${CML_OBJECT})
  endif()
  if (CML_OBJECT)
    set(lib_sources_def "$<TARGET_OBJECTS:${CML_LIBRARY_NAME}_obj>")
  else()
    set(lib_sources_def "${CML_SOURCE}")
  endif()
  # Local include directories.
  if (NOT (DEFINED CML_LOCAL_INCLUDE_DIRS OR
      "LOCAL_INCLUDE_DIRS" IN_LIST CML_KEYWORDS_MISSING_VALUES))
    set(CML_LOCAL_INCLUDE_DIRS
      "${CETMODULES_CURRENT_PROJECT_BINARY_DIR}" "${CETMODULES_CURRENT_PROJECT_SOURCE_DIR}")
  else()
    set(local_include_dirs)
    foreach (dir IN LISTS CML_LOCAL_INCLUDE_DIRS)
      if (IS_ABSOLUTE "${dir}")
        list(APPEND local_include_dirs "${dir}")
      else()
        foreach (base IN LISTS CETMODULES_CURRENT_PROJECT_BINARY_DIR CETMODULES_CURRENT_PROJECT_SOURCE_DIR)
          get_filename_component(tmp "${dir}" ABSOLUTE BASE_DIR "${base}")
          list(APPEND local_include_dirs "${tmp}")
        endforeach()
      endif()
    endforeach()
    set(CML_LOCAL_INCLUDE_DIRS "${local_include_dirs}")
  endif()
  set(extra_alias)
  set(lib_targets)
  cet_passthrough(FLAG IN_PLACE CML_EXCLUDE_FROM_ALL)
  foreach (lib_type IN LISTS lib_types)
    set(target_suffix)
    # This condition is in approximate likely order of frequency.
    if (lib_type STREQUAL "SHARED")
      set(lib_sources PRIVATE "${lib_sources_def}")
    elseif (lib_type STREQUAL "INTERFACE")
      set(lib_sources INTERFACE)
      foreach (source IN LISTS CML_SOURCE)
        if (NOT source MATCHES "(^(INTERFACE|PRIVATE|PUBLIC)|\\$<)")
          get_filename_component(source_path "${source}" ABSOLUTE)
          cet_installed_path(installed_path RELATIVE_VAR INCLUDE_DIR
            BASE_SUBDIR ${CML_INSTALLED_PATH_BASE} NOP
            "${source}")
          list(APPEND lib_sources "$<BUILD_INTERFACE:${source_path}>"
            "$<INSTALL_INTERFACE:${${CETMODULES_CURRENT_PROJECT_NAME}_INCLUDE_DIR}/${installed_path}>")
          continue() # Add this rather than the original.
        endif()
        # Add verbatim.
        list(APPEND lib_sources "${source}")
      endforeach()
    elseif (lib_type STREQUAL "MODULE")
      set(target_suffix M)
      set(lib_sources PRIVATE "${lib_sources_def}")
    elseif (lib_type STREQUAL "STATIC")
      set(target_suffix S)
      if (USE_BOOST_UNIT)
        set(lib_sources "${CML_SOURCE}")
      else()
        set(lib_sources "${lib_sources_def}")
      endif()
      set(lib_sources PRIVATE "$<IF:$<CONFIG:Release>,${CML_SOURCE},${lib_sources}>")
    elseif (lib_type STREQUAL "OBJECT")
      set(target_suffix _obj)
      set(lib_sources PUBLIC "${CML_SOURCE}")
    else()
      message(FATAL_ERROR "cet_make_library(): unknown library type ${lib_type}")
    endif()
    ##################
    set(lib_name "${CML_LIBRARY_NAME}${target_suffix}")
    set(lib_target "${CML_TARGET_NAME}${target_suffix}")
    if (CML_EXPORT_NAME)
      set(lib_export "${CML_EXPORT_NAME}${target_suffix}")
    else()
      unset(lib_export)
    endif()
    if (target_suffix AND
        (num_libtypes EQUAL 1 OR NOT
          CML_LIBRARY_NAME IN_LIST lib_targets))
      if (lib_export)
        set(extra_alias "${lib_export}")
      else()
        set(extra_alias "${lib_target}")
      endif()
      set(lib_target "${CML_TARGET_NAME}")
      set(lib_name "${CML_LIBRARY_NAME}")
    endif()
    ##################
    list(APPEND lib_targets ${lib_target})
    add_library(${lib_target} ${lib_type} ${CML_EXCLUDE_FROM_ALL})
    target_sources(${lib_target} ${lib_sources})
    target_include_directories(${lib_target}
      ${include_scope} "$<BUILD_INTERFACE:${CML_LOCAL_INCLUDE_DIRS}>"
      INTERFACE "$<INSTALL_INTERFACE:${${CETMODULES_CURRENT_PROJECT_NAME}_INCLUDE_DIR}>"
    )
    if (NOT lib_name STREQUAL lib_target)
      set_property(TARGET ${lib_target} PROPERTY
        OUTPUT_NAME "${lib_name}")
    endif()
    if (lib_export)
      set_property(TARGET ${lib_target} PROPERTY EXPORT_NAME ${lib_export})
      add_library(${namespace}::${lib_export} ALIAS ${lib_target})
    else()
      add_library(${namespace}::${lib_target} ALIAS ${lib_target})
    endif()
    if (lib_type STREQUAL OBJECT)
      set_property(TARGET ${lib_target} PROPERTY POSITION_INDEPENDENT_CODE TRUE)
    elseif (lib_type IN_LIST CML_STRIP_LIBS OR
        "STRIP_LIBS" IN_LIST CML_KEYWORDS_MISSING_VALUES)
      add_custom_command(TARGET ${lib_target} POST_BUILD
        COMMAND strip -x $<TARGET_FILE:${lib_target}>
        COMMENT "Stripping symbols from ${lib_type} library $<TARGET_FILE:${lib_target}>"
        )
    endif()
    if (lib_type STREQUAL "SHARED" OR lib_type STREQUAL "MODULE")
      set_target_properties(${lib_target} PROPERTIES
        $<$<BOOL:${CML_VERSION}>:VERSION ${CETMODULES_CURRENT_PROJECT_VERSION}>
        $<$<BOOL:${CML_SOVERSION}>:SOVERSION ${CML_SOVERSION}>)
    endif()
    target_link_libraries(${lib_target} ${liblist})
    if (CML_USE_BOOST_UNIT AND NOT lib_type STREQUAL "OBJECT")
      if (TARGET Boost::unit_test_framework)
        target_link_libraries(${lib_target} ${link_scope} Boost::unit_test_framework)
      else()
        target_link_libraries(${lib_target} ${link_scope} ${Boost_UNIT_TEST_FRAMEWORK_LIBRARY})
        target_compile_definitions(${lib_target} PRIVATE "BOOST_TEST_NO_OLD_TOOLS")
        if (NOT lib_target STREQUAL "STATIC")
          target_compile_definitions(${lib_target} PRIVATE "BOOST_TEST_DYN_LINK")
        endif()
      endif()
    endif()
  endforeach()
  if (CML_HEADERS_TARGET)
    if (TARGET ${CETMODULES_CURRENT_PROJECT_NAME}_headers)
      message(NOTICE "Requested headers target ${CETMODULES_CURRENT_PROJECT_NAME}_headers already exists - ignoring")
    else()
      add_library(${CETMODULES_CURRENT_PROJECT_NAME}_headers INTERFACE)
      target_include_directories(${CETMODULES_CURRENT_PROJECT_NAME}_headers INTERFACE
        "$<BUILD_INTERFACE:${CML_LOCAL_INCLUDE_DIRS}>"
        "$<INSTALL_INTERFACE:${${CETMODULES_CURRENT_PROJECT_NAME}_INCLUDE_DIR}>"
        )
      set(headers_alias headers)
      if (NOT namespace STREQUAL CETMODULES_CURRENT_PROJECT_NAME)
        string(PREPEND headers_alias "${CETMODULES_CURRENT_PROJECT_NAME}_")
      endif()
      set_property(TARGET ${CETMODULES_CURRENT_PROJECT_NAME}_headers PROPERTY EXPORT_NAME ${headers_alias})
      list(APPEND lib_targets ${CETMODULES_CURRENT_PROJECT_NAME}_headers)
      add_library(${namespace}::${headers_alias} ALIAS ${CETMODULES_CURRENT_PROJECT_NAME}_headers)
    endif()
  endif()
  # Install libraries.
  #
  # ...(except our object library).
  list(REMOVE_ITEM lib_targets ${CML_LIBRARY_NAME}_obj)
  if (NOT CML_NO_INSTALL)
    if (NOT CML_NO_EXPORT)
      _add_to_exported_targets(EXPORT_SET ${CML_EXPORT_SET} TARGETS ${lib_targets})
    endif()
    install(TARGETS ${lib_targets} EXPORT ${CML_EXPORT_SET}
	    RUNTIME DESTINATION "${${CETMODULES_CURRENT_PROJECT_NAME}_BIN_DIR}"
	    LIBRARY DESTINATION "${${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY_DIR}"
	    ARCHIVE DESTINATION "${${CETMODULES_CURRENT_PROJECT_NAME}_LIBRARY_DIR}")
  endif()
  if (TARGET ${CML_TARGET_NAME})
    # Return the target name if we've been asked.
    if (CML_LIBRARY_NAME_VAR)
      set(${CML_LIBRARY_NAME_VAR} "${CML_TARGET_NAME}" PARENT_SCOPE)
    endif()
    # Deal with aliases to primary target.
    foreach (alias IN LISTS CML_ALIAS extra_alias)
      add_library(${namespace}::${alias} ALIAS ${CML_TARGET_NAME})
    endforeach()
    if (NOT (CML_NO_INSTALL OR CML_NO_EXPORT))
      cet_export_alias(ALIAS_NAMESPACE ${namespace}
        EXPORT_SET ${CME_EXPORT_SET} ALIAS ${CML_ALIAS} ${extra_alias})
    endif()
  endif()
endfunction()

cmake_policy(POP)
