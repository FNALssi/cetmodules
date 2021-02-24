
# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetInstalledPath)

set(_cet_make_library_usage "")

function(cet_make_library)
  # Two-phase parsing to avoid confusion with e.g. INTERFACE in
  # LIBRARIES list.
  cmake_parse_arguments(PARSE_ARGV 0 CML
    "BASENAME_ONLY;MODULE;NO_INSTALL;NO_SOURCE;NOP;SHARED;STATIC;USE_BOOST_UNIT;USE_PROJECT_NAME;VERSION;WITH_STATIC_LIBRARY"
    "EXPORT;INSTALLED_PATH_BASE;LIBRARY_NAME;SOVERSION"
    "ALIASES;LIBRARIES;LOCAL_INCLUDE_DIRS;SOURCE;STRIP_LIBS")
  cmake_parse_arguments(CML
    "INTERFACE" "" "" ${CML_UNPARSED_ARGUMENTS})
  ##################
  # Argument verification.
  if (CML_NO_INSTALL AND CML_EXPORT)
    message(FATAL_ERROR "CML_NO_INSTALL and CML_EXPORT are mutually exclusive")
  endif()
  if (NOT (CML_NO_SOURCE OR CML_SOURCE OR
        "SOURCE" IN_LIST CML_KEYWORDS_MISSING_VALUES))
    message(FATAL_ERROR "SOURCE or NO_SOURCE is required")
  endif()
  ##################
  # Generate a useful library name.
  if (NOT CML_LIBRARY_NAME)
    cet_package_path(CML_LIBRARY_NAME SOURCE)
    if (CML_LIBRARY_NAME STREQUAL ".")
      if (NOT CML_USE_PROJECT_NAME)
        message(FATAL_ERROR "cet_make_library() invoked from ${PROJECT_NAME} top directory: \
LIBRARY_NAME or USE_PROJECT_NAME options required\
")
      else()
        unset(CML_LIBRARY_NAME)
      endif()
    elseif (CML_BASENAME_ONLY)
      get_filename_component(CML_LIBRARY_NAME "${CML_LIBRARY_NAME}" DIRECTORY)
    endif()
    if (CML_USE_PROJECT_NAME)
      string(JOIN "_" CML_LIBRARY_NAME ${PROJECT_NAME} ${CML_LIBRARY_NAME})
    endif()
    string(REGEX REPLACE "/+" "_" CML_LIBRARY_NAME "${CML_LIBRARY_NAME}")
  endif()
  ##################
  # Handle choices for library types.
  cet_passthrough(FLAG IN_PLACE CML_INTERFACE)
  cet_passthrough(FLAG IN_PLACE CML_MODULE)
  cet_passthrough(FLAG IN_PLACE CML_SHARED)
  cet_passthrough(FLAG IN_PLACE CML_STATIC)
  set(lib_types ${CML_INTERFACE} ${CML_MODULE} ${CML_SHARED} ${CML_STATIC})
  if (NOT lib_types)
    if (BUILD_SHARED_LIBS)
      list(APPEND lib_types SHARED)
    endif()
    if (BUILD_STATIC_LIBS OR CML_WITH_STATIC_LIBRARY)
      list(APPEND lib_types STATIC)
    endif()
  endif()
  list(LENGTH lib_types num_libtypes)
  set(lib_sources_obj)
  if (num_libtypes GREATER 1)
    if ("INTERFACE" IN_LIST lib_types)
      message(FATAL_ERROR "INTERFACE library is incompatible with any other library type!")
    endif()
    list(PREPEND lib_types OBJECT)
    set(lib_sources_obj "$<TARGET_OBJECTS:${CML_LIBRARY_NAME}_obj>")
  elseif(NOT lib_types STREQUAL "INTERFACE")
    set(lib_sources_obj "${CML_SOURCE}")
  endif()
  unset(extra_alias)
  set(lib_targets)
  foreach (lib_type IN LISTS lib_types)
    set(lib_target ${CML_LIBRARY_NAME})
    if (lib_type STREQUAL "SHARED")
      unset(target_suffix)
      set(lib_sources PRIVATE "${lib_sources_obj}")
    elseif (lib_type STREQUAL "OBJECT")
      set(target_suffix _obj)
      set(lib_sources PUBLIC "${CML_SOURCE}")
    elseif (lib_type STREQUAL "STATIC")
      set(target_suffix S)
      set(lib_sources PRIVATE "$<IF:$<CONFIG:Release>,${CML_SOURCE},${lib_sources_obj}>")
    elseif (lib_type STREQUAL "MODULE")
      set(target_suffix M)
      set(lib_sources PRIVATE "${lib_sources_obj}")
    elseif (lib_type STREQUAL "INTERFACE")
      unset(target_suffix)
      set(lib_sources INTERFACE)
      foreach (source IN LISTS CML_SOURCE)
        if (NOT source MATCHES "(^(INTERFACE|PRIVATE|PUBLIC)|\\$<)")
          get_filename_component(source_path "${source}" ABSOLUTE)
          cet_installed_path(installed_path RELATIVE_VAR INCLUDE_DIR
            BASE_SUBDIR ${CML_INSTALLED_PATH_BASE} NOP
            "${source}")
          list(APPEND lib_sources "$<BUILD_INTERFACE:${source_path}>"
            "$<INSTALL_INTERFACE:${${PROJECT_NAME}_INCLUDE_DIR}/${installed_path}>")
          continue() # Add this rather than the original.
        endif()
        # Add verbatim.
        list(APPEND lib_sources "${source}")
      endforeach()
    else()
      message(FATAL_ERROR "cet_make_library(): unknown library type ${lib_type}")
    endif()
    if (target_suffix)
      if (num_libtypes GREATER 1)
        string(APPEND lib_target "${target_suffix}")
      else()
        set(extra_alias "${lib_target}${target_suffix}")
      endif()
    endif()
    list(APPEND lib_targets ${lib_target})
    add_library(${lib_target} ${lib_type})
    target_sources(${lib_target} ${lib_sources})
    if (lib_type STREQUAL OBJECT)
      set_property(TARGET ${lib_target} PROPERTY POSITION_INDEPENDENT_CODE TRUE)
    elseif (lib_type IN_LIST CML_STRIP_LIBS OR
        STRIP_LIBS IN_LIST CML_KEYWORDS_MISSING_VALUES)
      add_custom_command(TARGET ${lib_target} POST_BUILD
        COMMAND strip -S $<TARGET_FILE:${lib_target}>
        COMMENT "Stripping symbols from ${lib_type} library $<TARGET_FILE:${lib_target}>")
    endif()
    if (target_suffix)
      set_property(TARGET ${lib_target} PROPERTY OUTPUT_NAME ${CML_LIBRARY_NAME})
    elseif (lib_type STREQUAL SHARED)
      set_target_properties(${lib_target} PROPERTIES
        $<$<BOOL:${CML_VERSION}>:VERSION ${PROJECT_VERSION}>
        $<$<BOOL:${CML_SOVERSION}>:SOVERSION ${CML_SOVERSION}>)
    endif()
  endforeach()
  # Target alias namespace.
  _calc_namespace(alias_namespace ${CML_EXPORT})
  # Local include directories.
  if (NOT (DEFINED CML_LOCAL_INCLUDE_DIRS OR
      "LOCAL_INCLUDE_DIRS" IN_LIST CML_KEYWORDS_MISSING_VALUES))
    set(CML_LOCAL_INCLUDE_DIRS
      "${PROJECT_BINARY_DIR}" "${PROJECT_SOURCE_DIR}")
  else()
    set(local_include_dirs)
    foreach (dir IN LISTS CML_LOCAL_INCLUDE_DIRS)
      if (IS_ABSOLUTE "${dir}")
        list(APPEND local_include_dirs "${dir}")
      else()
        foreach (base IN LISTS PROJECT_BINARY_DIR PROJECT_SOURCE_DIR)
          get_filename_component(tmp "${dir}" ABSOLUTE BASE_DIR "${base}")
          list(APPEND local_include_dirs "${tmp}")
        endforeach()
      endif()
    endforeach()
    set(CML_LOCAL_INCLUDE_DIRS "${local_include_dirs}")
  endif()
  cet_process_liblist(liblist ${CML_LIBRARIES})
  # Library links.
  if (CML_USE_BOOST_UNIT)
    cet_find_package(Boost PRIVATE QUIET COMPONENTS unit_test_framework REQUIRED)
    list(APPEND liblist PRIVATE Boost::unit_test_framework)
  endif()
  # Go through each library target.
  foreach (target IN LISTS lib_targets)
    add_library(${alias_namespace}::${target} ALIAS ${target})
    # Building ${PROJECT_NAME} and using it as a dependency from the
    # build area will utilize CML_LOCAL_INCLUDE_DIRS, while using
    # ${PROJECT_NAME} as an installed dependency will utilize only
    # ${PROJECT_NAME}_INCLUDE_DIR as a path relative to
    # INSTALL_PREFIX. Note the double quotes around the whole generator
    # expression to ensure the correct interpretation of the list inside
    # it.
    if (CML_INTERFACE)
      set(scope INTERFACE)
    else()
      set(scope PUBLIC)
    endif()
    target_include_directories(${target}
      ${scope} "$<BUILD_INTERFACE:${CML_LOCAL_INCLUDE_DIRS}>")
    target_include_directories(${target}
      INTERFACE "$<INSTALL_INTERFACE:${${PROJECT_NAME}_INCLUDE_DIR}>")
    target_link_libraries(${target} ${liblist})
  endforeach()
  # Install libraries.
  #
  # ...(except our object library).
  list(REMOVE_ITEM lib_targets ${CML_LIBRARY_NAME}_obj)
  if (NOT CML_NO_INSTALL)
    cet_register_export_name(CML_EXPORT)
    _add_to_exported_targets(EXPORT ${CML_EXPORT} TARGETS ${lib_targets})
    install(TARGETS ${lib_targets} EXPORT ${CML_EXPORT}
	    RUNTIME DESTINATION "${${PROJECT_NAME}_BIN_DIR}"
	    LIBRARY DESTINATION "${${PROJECT_NAME}_LIBRARY_DIR}"
	    ARCHIVE DESTINATION "${${PROJECT_NAME}_LIBRARY_DIR}")
  endif()
  if (TARGET ${CML_LIBRARY_NAME})
    # Deal with aliases to primary target.
    foreach (alias IN LISTS CML_ALIASES extra_alias)
      add_library(${alias_namespace}::${alias} ALIAS ${CML_LIBRARY_NAME})
      if (NOT CML_NO_INSTALL)
        _cet_export_import_cmd(TARGETS ${alias_namespace}::${alias} COMMANDS
          "add_library(${alias_namespace}::${alias} ALIAS ${${PROJECT_NAME}_${CML_EXPORT}_NAMESPACE}::${CML_LIBRARY_NAME})")
      endif()
    endforeach()
  endif()
endfunction()

cmake_policy(POP)
