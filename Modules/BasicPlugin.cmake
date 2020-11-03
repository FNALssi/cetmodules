# macros for building plugin libraries
#
# The plugin type is expected to be service, source, or module,
# but we do not enforce this.
#
# USAGE:
# basic_plugin( <name> <plugin type>
#                [[NOP] <libraries>]
#                [USE_BOOST_UNIT]
#                [ALLOW_UNDERSCORES]
#                [BASENAME_ONLY]
#                [USE_PRODUCT_NAME]
#                [NO_INSTALL]
#                [SOURCE <sources>]
#   )
#
# The plugin library's name is constructed from the specified name, its
# specified plugin type (eg service, module, source), and (unless
# BASENAME_ONLY is specified) the package subdirectory path (replacing
# "/" with "_").
#
# Options:
#
# ALLOW_UNDERSCORES
#
#    Allow underscores in subdirectory names. Discouraged, as it creates
#    a possible ambiguity in the encoded plugin library name
#    (art_test/XX is indistinguishable from art/test/XX).
#
# BASENAME_ONLY
#
#    Omit the subdirectory path from the library name. Discouraged, as
#    it creates an ambiguity between modules with the same source
#    filename in different packages or different subdirectories within
#    the same package. The latter case is not possible however, because
#    CMake will throw an error because the two CMake targets will have
#    the same name and that is not permitted. Mutually exclusive with
#    USE_PRODUCT_NAME.
#
# NO_INSTALL
#
#    If specified, the plugin library will not be part of the installed
#    product (use for test modules, etc.).
#
# NOP
#
#    Dummy option for the purpose of separating (say) multi-option
#    arguments from non-option arguments.
#
# SOURCE
#
#    If specified, the provided sources will be used to create the
#    library. Otherwise, the generated name <name>_<plugin_type>.cc will
#    be used and this will be expected to be found in
#    ${CMAKE_CURRENT_SOURCE_DIR}.
#
# USE_BOOST_UNIT
#
#    Allow the use of Boost Unit Test facilities.
#
# USE_PRODUCT_NAME
#
#    Prepend the product name to the plugin library name. Mutually
#    exclusive with BASENAME_ONLY.
#
########################################################################

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetPackagePath)
include(CetProcessLiblist)

set(cet_bp_flags ALLOW_UNDERSCORES BASENAME_ONLY NOP NO_INSTALL USE_BOOST_UNIT USE_PRODUCT_NAME VERSION)
set(cet_bp_one_arg_opts EXPORT LIB_TYPE SOVERSION)
set(cet_bp_list_options ALIASES LIBRARIES LOCAL_INCLUDE_DIRS SOURCE)

# Basic plugin libraries.
function(basic_plugin NAME TYPE)
  cmake_parse_arguments(PARSE_ARGV 2 BP
    "${cet_bp_flags}" "${cet_bp_one_arg_opts}" "${cet_bp_list_options}")
  if (BP_UNPARSED_ARGUMENTS)
    warn_deprecated("unprocessed arguments" NEW "LIBRARIES")
    list(APPEND BP_LIBRARIES ${BP_UNPARSED_ARGUMENTS})
  endif()
  if (BP_BASENAME_ONLY AND BP_USE_PRODUCT_NAME)
    message(FATAL_ERROR "BASENAME_ONLY AND USE_PRODUCT_NAME are mutually exclusive")
  endif()
  if (BP_BASENAME_ONLY)
    set(plugin_name "${NAME}_${TYPE}")
  else()
    cet_package_path(CURRENT_SUBDIR)
    if (NOT BP_ALLOW_UNDERSCORES)
      if (CURRENT_SUBDIR MATCHES _)
        message(FATAL_ERROR  "found underscore in plugin subdirectory: ${CURRENT_SUBDIR}" )
      endif()
      if (NAME MATCHES _)
        message(FATAL_ERROR  "found underscore in plugin name: ${NAME}" )
      endif()
    endif()
    string(REPLACE "/" "_" plugname "${CURRENT_SUBDIR}")
    if (BP_USE_PRODUCT_NAME)
      set(plugname "${PROJECT_NAME}_${plugname}")
    endif()
    set(plugin_name "${plugname}_${NAME}_${TYPE}")
  endif()
  if (NOT BP_SOURCE)
    set(BP_SOURCE "${NAME}_${TYPE}.cc")
  endif()
  set(cml_args)
  foreach (kw IN ITEMS ALIASES EXPORT LIB_TYPE LIBRARIES LOCAL_INCLUDE_DIRS SOURCE SOVERSION)
    cet_passthrough(APPEND BP_${kw} cml_args)
  endforeach()
  foreach (kw IN ITEMS NO_INSTALL USE_BOOST_UNIT VERSION)
    cet_passthrough(FLAG APPEND BP_${kw} cml_args)
  endforeach()
  if (NOT BP_LIB_TYPE)
    set(BP_LIB_TYPE MODULE)
  endif()
  cet_make_library(LIBRARY_NAME ${plugin_name} ${cml_args})
endfunction()

cmake_policy(POP)
