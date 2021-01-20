#[================================================================[.rst:
BasicPlugin
===========

Module defining the function :cmake:command:`basic_plugin` to generate a generic
plugin module.
#]================================================================]

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(CetPackagePath)
include(CetProcessLiblist)

set(cet_bp_flags ALLOW_UNDERSCORES BASENAME_ONLY NOP NO_INSTALL USE_BOOST_UNIT USE_PRODUCT_NAME VERSION)
set(cet_bp_one_arg_opts EXPORT LIB_TYPE SOVERSION)
set(cet_bp_list_options ALIASES LIBRARIES LOCAL_INCLUDE_DIRS SOURCE)

#[================================================================[.rst:
.. cmake:command:: basic_plugin

   Create a plugin module.

   **Synopsis:**
     .. code-block:: cmake

        basic_plugin(<name> <type> [<options>])

   **Options:**
     ``ALIASES <alias>...``
       Create the specified CMake alias targets to the plugin.

     ``ALLOW_UNDERSCORES``
       Normally, neither ``<name>`` nor ``<type>`` may contain
       underscores in order to avoid possible ambiguities. Allow them
       with this option at your own risk.

     ``BASENAME_ONLY``
       Do not add the relative path (directories delimited by ``_``) to
       the front of the plugin library name.

     ``EXPORT <export-name>``
       Add the library to the ``<export-name>`` export set.

     ``LIB_TYPE SHARED|STATIC|MODULE``
       Set the library type. Defaults to ``SHARED``.

     ``LIBRARIES <library-dependency>...``
       Dependencies against which to link.

     ``LOCAL_INCLUDE_DIRS <dir>...``
       Headers may be found in ``<dir>``... at build time.

     ``NOP``
       Option / argument disambiguator; no other function.

     ``NO_INSTALL``
       Do not install the generated plugin.

     ``SOURCE <source>...``
       Specify sources to compile into the plugin.

     ``SOVERSION <version>``
       The library's compatibility version (*cf*
       :cmake:prop_tgt:`SOVERSION`).

     ``USE_BOOST_UNIT``
       The plugin uses Boost unit test functions and should be compiled
       and linked accordingly.

     ``USE_PRODUCT_NAME``

       .. deprecated:: 2.0
          use ``USE_PACKAGE_NAME`` instead.

     ``USE_PACKAGE_NAME``
       The package name will be prepended to the pluign library name,
       separated by ``_``

     ``VERSION``
       The library's build version will be set to
       :cmake:variable:`PROJECT_NAME` (*cf* :cmake:prop_tgt:`VERSION`).

   **Non-option arguments:**

     ``<name>``

     The name stem for the library to be generated.

     ``<type>``

     The type of plugin to be generated.

   .. note:: The plugin generated will be named ``<prefix><name>_<type><suffix>``.

   .. seealso:: :cmake:command:`cet_cmake_library`
#]================================================================]
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
