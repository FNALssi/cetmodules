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

set(cet_bp_flags ALLOW_UNDERSCORES BASENAME_ONLY NOP NO_EXPORT NO_INSTALL USE_BOOST_UNIT USE_PRODUCT_NAME VERSION)
set(cet_bp_one_arg_opts EXPORT_SET SOVERSION)
set(cet_bp_list_options ALIASES IMPL_SOURCE LIBRARIES LOCAL_INCLUDE_DIRS PLUGIN_SOURCE SOURCE)

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

     ``EXPORT_SET <export-name>``
       Add the library to the ``<export-name>`` export set.

     ``IMPL_SOURCE <impl-source>``
       Specify sources to compile into the plugin's interface
       implementation library, if it has an interface header. These
       should be separated from the plugin registration sources to avoid
       violating the one definition rule.

       .. seealso:: ``PLUGIN_SOURCE``

     ``LIBRARIES <library-dependency>...``
       Dependencies against which to link.

       .. note:: In addition to the usual signifiers of ``INTERFACE``,
       ``PRIVATE``, and ``PUBLIC``, this option understands ``PLUGIN` to
       denote specifically dependencies of the library containing the
       plugin registration code (as distinct from the interface
       implementation library, if it exists).

     ``LOCAL_INCLUDE_DIRS <dir>...``
       Headers may be found in ``<dir>``... at build time.

     ``NOP``
       Option / argument disambiguator; no other function.

     ``NO_INSTALL``
       Do not install the generated plugin.

     ``PLUGIN_SOURCE <plugin-source>``
       Specify sources to compile into the plugin registration library;
       defaults to ``<name>_<type>.cc``.

     ``SOURCE <source>...``
       Specify sources to compile into the plugin.

       .. deprecated:: 2.10
          use ``IMPL_SOURCE``, ``PLUGIN_SOURCE`` and ``LIBRARIES PLUGIN`` instead.

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
       The package name will be prepended to the plugin library name,
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

   .. seealso:: :cmake:command:`cet_make_library`
#]================================================================]
function(basic_plugin NAME SUFFIX)
  cmake_parse_arguments(PARSE_ARGV 2 BP
    "${cet_bp_flags}" "${cet_bp_one_arg_opts}" "${cet_bp_list_options}")
  set(thunk)
  if (BP_UNPARSED_ARGUMENTS)
    warn_deprecated("unprocessed arguments" NEW "LIBRARIES")
    list(APPEND BP_LIBRARIES ${BP_UNPARSED_ARGUMENTS})
  endif()
  if (BP_BASENAME_ONLY AND BP_USE_PRODUCT_NAME)
    message(FATAL_ERROR "BASENAME_ONLY AND USE_PRODUCT_NAME are mutually exclusive")
  endif()
  if (BP_BASENAME_ONLY)
    set(plugin_base "${NAME}")
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
    string(REPLACE "/" "_" plugin_base "${CURRENT_SUBDIR}")
    if (BP_USE_PRODUCT_NAME)
      string(JOIN "_" plugin_base "${PROJECT_NAME}" "${plugin_base}")
    endif()
    string(JOIN "_" plugin_base  "${plugin_base}" "${NAME}")
  endif()
  if (BP_SOURCE)
    warn_deprecated("SOURCE" NEW "IMPL_SOURCE, PLUGIN_SOURCE and LIBRARIES PLUGIN")
    if (BP_PLUGIN_SOURCE)
      message(FATAL_ERROR "SOURCE and PLUGIN_SOURCE are mutually exclusive")
    endif()
    set(BP_PLUGIN_SOURCE "${BP_SOURCE}")
  elseif (NOT BP_PLUGIN_SOURCE)
    set(BP_PLUGIN_SOURCE "${NAME}_${SUFFIX}.cc")
  endif()
  set(shared_ok)
  if (BP_IMPL_SOURCE STREQUAL BP_PLUGIN_SOURCE)
    # Caller knows what they're doing.
    unset(BP_IMPL_SOURCE)
    set(shared_ok TRUE)
  endif()
  set(cml_args)
  ##################
  # These items are common to implementation and plugin libraries.
  foreach (kw IN ITEMS EXPORT_SET LOCAL_INCLUDE_DIRS SOVERSION)
    cet_passthrough(APPEND BP_${kw} cml_common_args)
  endforeach()
  foreach (kw IN ITEMS BASENAME_ONLY NO_INSTALL
      USE_PRODUCT_NAME VERSION)
    cet_passthrough(FLAG APPEND BP_${kw} cml_common_args)
  endforeach()
  # These items are only for the implementation library.
  foreach (kw IN ITEMS ALIASES)
    cet_passthrough(APPEND BP_${kw} cml_impl_args)
  endforeach()
  foreach (kw IN ITEMS NO_EXPORT USE_BOOST_UNIT)
    cet_passthrough(FLAG APPEND BP_${kw} cml_impl_args)
  endforeach()
  ##################
  set(thunk)
  cmake_parse_arguments(BPL "" "" "INTERFACE;PRIVATE;PUBLIC;PLUGIN" ${BP_LIBRARIES})
  list(APPEND BPL_PUBLIC ${BPL_UNPARSED_ARGUMENTS})
  if (NOT BP_IMPL_SOURCE) # See if we can find one.
    get_filename_component(if_plugin_impl "${NAME}.cc" REALPATH)
    if (EXISTS "${if_plugin_impl}")
      set(BP_IMPL_SOURCE "${NAME}.cc")
    endif()
  endif()
  foreach (kw IN ITEMS INTERFACE PUBLIC PRIVATE)
    cet_passthrough(IN_PLACE BPL_${kw})
  endforeach()
  if (BP_IMPL_SOURCE OR NOT BPL_PUBLIC)
    set(LIB_TYPE MODULE)
    if (BP_IMPL_SOURCE)
      list(PREPEND BPL_PLUGIN "${plugin_base}_${SUFFIX}")
      cet_make_library(LIBRARY_NAME "${plugin_base}_${SUFFIX}"
        SOURCE ${BP_IMPL_SOURCE}
        LIBRARIES ${BPL_INTERFACE} ${BPL_PUBLIC} ${BPL_PRIVATE} NOP
        ${cml_common_args} ${cml_impl_args}
        )
      # For backward compatibility purposes, we retain the vanilla
      # target name but have a different name for the implementation
      # library on disk.
      set_target_properties("${plugin_base}_${SUFFIX}"
        PROPERTIES OUTPUT_NAME "${plugin_base}_${SUFFIX}_impl"
      )
      # Thunk the target name of the plugin library so we don't attempt
      # to link to it, but retain the vanilla library name for backward
      # compatibility.
      set(thunk _plugin)
      # Trim the plugin's library list.
      set(BP_LIBRARIES PRIVATE "${plugin_base}_${SUFFIX}" ${BPL_PLUGIN})
      unset(cml_impl_args)
    else()
      set(BP_LIBRARIES ${BPL_PRIVATE} PRIVATE ${BPL_PLUGIN})
      list(REMOVE_DUPLICATES BP_LIBRARIES)
      list(PREPEND BP_LIBRARIES ${BPL_INTERFACE} ${BPL_PUBLIC})
    endif()
  else()
    set(LIB_TYPE SHARED)
    set(BP_LIBRARIES ${BPL_INTERFACE} ${BPL_PUBLIC} ${BPL_PRIVATE} PRIVATE ${BPL_PLUGIN})
    if (NOT shared_ok AND CET_WARN_DEPRECATED)
      message(AUTHOR_WARNING "prefer separate compilation units for implementation (IMPL_SOURCE) and plugin registration macros (PLUGIN_SOURCE, LIBRARIES PLUGIN)")
    endif()
  endif()
  ##################
  # These items are applicable only to the implementation library.
  cet_passthrough(IN_PLACE BP_PLUGIN_SOURCE
    KEYWORD SOURCE EMPTY_KEYWORD NO_SOURCE)
  ##################
  # Make the plugin library, to which we should not normally link
  # directly (see PLUGIN_SOURCE, above).
  #
  # Module-type libraries containing only plugin registration code can
  # be stripped.
  cet_passthrough(FLAG APPEND thunk KEYWORD STRIP_LIBS cml_impl_args)
  if (LIB_TYPE STREQUAL "MODULE" AND NOT NO_INSTALL)
    # We don't want the plugin-only library visible as an exported target.
    list(APPEND cml_impl_args NO_EXPORT)
  endif()
  cet_make_library(LIBRARY_NAME "${plugin_base}_${SUFFIX}${thunk}"
    ${LIB_TYPE}
    ${BP_PLUGIN_SOURCE}
    ${cml_common_args} ${cml_impl_args}
    LIBRARIES ${BP_LIBRARIES}
  )
  if (thunk)
    set_target_properties(${plugin_base}_${SUFFIX}${thunk}
      PROPERTIES OUTPUT_NAME "${plugin_base}_${SUFFIX}"
    )
  endif()
endfunction()

cmake_policy(POP)
