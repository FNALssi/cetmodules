#[================================================================[.rst:
CetMakeCommand
--------------

Defines the deprecated function :command:`cet_make`.

#]================================================================]

include_guard()

include(CetCMakeUtils)
include(CetMakeLibrary)
include(CetMake)
include(Compatibility)

set(_cet_make_usage "\
USAGE: cet_make([USE_(PROJECT|PRODUCT)_NAME|LIBRARY_NAME <library-name>]
                [LIB_LIBRARIES <library-dependencies>...]
                [LIB_LOCAL_INCLUDE_DIRS <include-dirs>...]
                [DICT_LIBRARIES <dict-library-dependencies>...]
                [DICT_LOCAL_INCLUDE_DIRS <include-dirs>...]
                [SUBDIRS <source-subdir>...]
                [EXCLUDE ([REGEX] <exclude>...)...]
                [LIB_ALIAS <alias>...]
                [VERSION] [SOVERSION <API-version>]
                [EXPORT_SET <export-name>]
                [NO_INSTALL|INSTALL_LIBS_ONLY]
                [NO_DICTIONARY] [USE_PRODUCT_NAME] [WITH_STATIC_LIBRARY])\
")

set(_cet_make_flags BASENAME_ONLY EXCLUDE_FROM_ALL INSTALL_LIBS_ONLY
  LIB_INTERFACE LIB_MODULE LIB_OBJECT LIB_ONLY LIB_SHARED LIB_STATIC
  NO_DICTIONARY NO_EXPORT NO_INSTALL NO_LIB NO_LIB_SOURCE NOP
  USE_PRODUCT_NAME USE_PROJECT_NAME VERSION WITH_STATIC_LIBRARY)

set(_cet_make_one_arg_options EXPORT_SET LIBRARY_NAME LIBRARY_NAME_VAR
  SOVERSION)

set(_cet_make_list_options DICT_LIBRARIES DICT_LOCAL_INCLUDE_DIRS
  EXCLUDE LIB_ALIAS LIB_LIBRARIES LIB_LOCAL_INCLUDE_DIRS LIB_SOURCE
  LIBRARIES SUBDIRS)

function(cet_make)
  cmake_parse_arguments(PARSE_ARGV 0 CM
    "${_cet_make_flags}"
    "${_cet_make_one_arg_options}"
    "${_cet_make_list_options}")
  # Argument verification.
  _cet_verify_cet_make_args()
  ##################
  # Prepare common passthroughs.
  cet_passthrough(IN_PLACE CM_EXPORT_SET)
  foreach (flag EXCLUDE_FROM_ALL NO_EXPORT NO_INSTALL USE_PROJECT_NAME VERSION)
    cet_passthrough(FLAG IN_PLACE CM_${flag})
  endforeach()
  ##################
  if (NOT (CM_NO_LIB OR "LIB_SOURCE" IN_LIST CM_KEYWORDS_MISSING_VALUES))
    # We want a library.
    _cet_maybe_make_library()
    if (CM_LIBRARY_NAME_VAR)
      set(${CM_LIBRARY_NAME_VAR} "${${CM_LIBRARY_NAME_VAR}}" PARENT_SCOPE)
    endif()
  endif()
  if (CM_LIB_ONLY)
    return()
  endif()
  # Look for the makings of a dictionary and decide how to make it.
  if (NOT CM_NO_DICTIONARY AND
      EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/classes.h")
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/classes_def.xml")
      cet_passthrough(IN_PLACE KEYWORD LOCAL_INCLUDE_DIRS
        CM_DICT_LOCAL_INCLUDE_DIRS)
      include(BuildDictionary)
      build_dictionary(${CM_LIBRARY_NAME}
        DICTIONARY_LIBRARIES ${CM_DICT_LIBRARIES} NOP
        ${CM_DICT_LOCAL_INCLUDE_DIRS} ${CM_USE_PROJECT_NAME}
        ${CM_EXPORT_SET} ${CM_NO_EXPORT} ${CM_NO_INSTALL}
        ${CM_VERSION})
    elseif (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/LinkDef.h")
      include(CetRootCint)
      cet_rootcint(${CM_LIBRARY_NAME}
        ${CM_DICT_LOCAL_INCLUDE_DIRS} ${CM_USE_PROJECT_NAME}
        ${CM_EXPORT_SET} ${CM_NO_EXPORT} ${CM_NO_INSTALL}
        ${CM_VERSION})
    endif()
  endif()
endfunction()

macro(_cet_verify_cet_make_args)
  if (CM_UNPARSED_ARGUMENTS)
    warn_deprecated("non-option arguments" NEW "LIBRARIES")
  endif()
  if (CM_NO_INSTALL AND CM_INSTALL_LIBS_ONLY)
    message(FATAL_ERROR "cet_make(): NO_INSTALL and INSTALL_LIBS_ONLY are mutually exclusive")
  endif()
  if (CM_USE_PROJECT_NAME AND CM_USE_PRODUCT_NAME)
    message(WARNING "cet_make(): USE_PRODUCT_NAME and USE_PROJECT_NAME are synonymous")
    unset(CM_USE_PRODUCT_NAME)
  elseif (CM_USE_PROJECT_NAME OR CM_USE_PRODUCT_NAME)
    set(CM_USE_PROJECT_NAME TRUE)
    unset(CM_USE_PRODUCT_NAME)
  endif()
endmacro()

function(_cet_maybe_make_library)
  if (NOT (CM_NO_LIB_SOURCE OR CM_LIB_SOURCE))
    # Look for suitable source files for the library.
    unset(src_file_globs)
    cet_source_file_extensions(source_file_patterns)
    list(TRANSFORM source_file_patterns PREPEND "*.")
    set(src_file_globs ${source_file_patterns})
    foreach(sub IN LISTS CM_SUBDIRS CMAKE_CURRENT_BINARY_DIR)
      list(TRANSFORM source_file_patterns PREPEND "${sub}/"
        OUTPUT_VARIABLE sub_globs)
      list(APPEND src_file_globs ${sub_globs})
    endforeach()
    if (src_file_globs)
      # Invoke CONFIGURE_DEPENDS to force the build system to regenerate
      # if the result of this glob changes. Note that in the case of
      # generated files (in and under ${CMAKE_CURRENT_BINARY_DIR}), this
      # can only be accurate for files generated at configure rather
      # than generate or build time.
      file(GLOB CM_LIB_SOURCE CONFIGURE_DEPENDS ${src_file_globs})
    endif()
    cet_exclude_files_from(CM_LIB_SOURCE ${CM_EXCLUDE} NOP
      REGEX [=[_(generator|module|plugin|service|source|tool)\.cc$]=]
      [=[_dict\.cpp$]=] NOP)
  endif()
  if (CM_LIB_SOURCE OR CM_NO_LIB_SOURCE) # We have a library to build.
    set(cml_args)
    # Simple passthrough.
    cet_passthrough(IN_PLACE CM_LIBRARY_NAME)
    if (CM_LIBRARY_NAME_VAR)
      list(APPEND cml_args LIBRARY_NAME_VAR "${CM_LIBRARY_NAME_VAR}")
    endif()
    cet_passthrough(APPEND CM_SO_VERSION cml_args)
    foreach (kw IN ITEMS BASENAME_ONLY INSTALL_LIBS_ONLY
        WITH_STATIC_LIBRARY)
      cet_passthrough(FLAG APPEND CM_${kw} cml_args)
    endforeach()
    # Deal with synonyms.
    cet_passthrough(APPEND VALUES ${CM_LIB_LOCAL_INCLUDE_DIRS}
      ${CM_LOCAL_INCLUDE_DIRS} KEYWORD LOCAL_INCLUDE_DIRS
      cml_args)
    # Deal with LIB_XXX.
    foreach (kw IN ITEMS INTERFACE MODULE OBJECT SHARED STATIC)
      cet_passthrough(FLAG APPEND KEYWORD ${kw} CM_LIB_${kw} cml_args)
    endforeach() 
    cet_passthrough(APPEND KEYWORD ALIAS CM_LIB_ALIAS cml_args)
    # Generate the library.
    cet_make_library(${CM_LIBRARY_NAME} ${CM_EXPORT_SET} ${CM_EXCLUDE_FROM_ALL}
      ${CM_NO_EXPORT} ${CM_NO_INSTALL} ${CM_VERSION} ${CM_USE_PROJECT_NAME} ${cml_args}
      LIBRARIES ${CM_LIBRARIES} ${CM_LIB_LIBRARIES} NOP
      SOURCE ${CM_LIB_SOURCE})
    if (CM_LIBRARY_NAME_VAR)
      set(${CM_LIBRARY_NAME_VAR} "${${CM_LIBRARY_NAME_VAR}}" PARENT_SCOPE)
    endif()
  endif()
endfunction()
