#[================================================================[.rst:
X
=
#]================================================================]

# Avoid unnecessary repeat inclusion.
include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

function(cet_process_liblist RESULT_VAR)
  cet_convert_target_args(${ARGV})
  set(${RESULT_VAR} "${${RESULT_VAR}}" PARENT_SCOPE)
endfunction()

function(cet_convert_target_args RESULT_VAR DEP_TARGET)
  set(RESULTS)
  set(scope PRIVATE)
  foreach (arg IN LISTS ARGN)
    if (arg MATCHES "^(INTERFACE|PRIVATE|PUBLIC)$")
      set(scope "${arg}")
    elseif (TARGET "${arg}")
      get_target_property(target_type "${arg}" TYPE)
      if (target_type STREQUAL "MODULE_LIBRARY")
        message(SEND_ERROR "
cannot link to target ${arg} of CMake type \"${target_type}\".
Separate implementation from plugin registration code (e.g. X.cc vs \
X_<plugin-suffix>.cc) (strongly recommended), specify PUBLIC dependencies to \
basic_plugin() (temporary solution only), or set \
${CETMODULES_CURRENT_PROJECT_NAME} _MODULE_PLUGINS to FALSE (not recommended)\
")
      endif()
    elseif (NOT arg MATCHES
        "(/|::|^((-|\\$<)|(debug|general|optimized)$))")
      _cet_convert_target_arg("${arg}" arg)
    endif()
    list(APPEND RESULTS "${arg}")
  endforeach()
  set(${RESULT_VAR} "${RESULTS}" PARENT_SCOPE)
endfunction()

function(_cet_convert_target_arg ARG RESULT_VAR)
  set(DOLLAR "@CET_DOLLAR@")
  # Can we convert it to an uppercase variable we can substitute?
  string(TOUPPER "${ARG}" ${ARG}_UC)
  if (${${ARG}_UC})
    # Delay expansion for variables resolving to paths.
    if (${${ARG}_UC} MATCHES "/")
	    set(RESULT "PRIVATE" "${${${ARG}_UC}}" "INTERFACE"
        "$<BUILD_INTERFACE:${${${ARG}_UC}}>"
        "$<INSTALL_INTERFACE:${DOLLAR}{${${ARG}_UC}}>" ${scope})
    else()
      set(RESULT "${${${ARG}_UC}}")
    endif()
  elseif (ARG MATCHES "/") # Definitely *not* a target.
    set(RESULT "${ARG}")
  else ()
    # Likely a target, which may or may not have been defined yet.
    #
    # Put mechanisms in place to catch link problems at link time if we
    # can't detect them earlier (see 'if (TARGET "${arg}") ...' in
    # cet_convert_target_args(), above).
    set(error_file "$<MAKE_C_IDENTIFIER:${DEP_TARGET}-${ARG}>-ERROR.txt")
    set(gen_condition "$<AND:$<TARGET_EXISTS:${ARG}>,$<STREQUAL:MODULE_LIBRARY,$<TARGET_PROPERTY:$<IF:$<BOOL:$<TARGET_PROPERTY:${ARG},ALIASED_TARGET>>,$<TARGET_PROPERTY:${ARG},ALIASED_TARGET>,${ARG}>,TYPE>>>")
	  set(RESULT "$<IF:${gen_condition},UNLINKABLE-MODULE-LIBRARY-TARGET-SEE-${CMAKE_CURRENT_BINARY_DIR}/${error_file},${ARG}>")
    file(GENERATE OUTPUT "${error_file}" CONTENT "\
Target ${ARG} is of CMake type MODULE_LIBRARY, *not* SHARED_LIBRARY. This means that it cannot be a library dependency, but used only as a dynamically-loaded plugin module.

${ARG} was not defined at the time CMake processed instructions for target ${DEP_TARGET}, so was not able to detect the error prior to ${DEP_TARGET}'s link operation. Please:

1. Define all targets *prior* to their use as dependencies to enable CMake to detect problems at configuration / generation time rather than at build time.

2. When generating plugins, ensure that the implementation code (allowing other code to access plugin functionality) is compiled separately and inserted into a different library from the plugin registration code (usually a CPP macro defined by your plugin framework). cetmodules' basic_plugin() CMake function will do this if instructed explicitly, or if the source code files follow the expected convention. See the documentation for basic_plugin() for details.

3. Use appropriate build system and/or linker mechanisms to ensure all dependencies for libraries and executables are resolved at link-time to avoid runtime failures which may be expensive in terms of wasted CPU cycles. With cetmodules, invoke set_compiler_flags(... NO_UNDEFINED ...).

4. Check the build tree for other *-ERROR.txt files and resolve them similarly prior to attempting another build.\
"
      CONDITION ${gen_condition})
  endif()
  set(${RESULT_VAR} "${RESULT}" PARENT_SCOPE)
endfunction()

cmake_policy(POP)
