##########################################################################
# cet_make_completions
#
# This is a facility that generates bash completions for any
# executables that follow the Boost Program Options library output
# format.
#
# The call syntax is:
#
#   cet_make_completions(<exec> [customizations file])
#
# where the customizations file is optional.  The generated file is
# called "<exec>_completions", and it is placed in the current binary
# directory.
#
# To prevent CSH environments from executing the bash commands, a
# check is made at the top of the file which exits if the environment
# is CSH.
#
# The automatically generated bash completions simply allow
# completions for any program options, irrespective of any other
# program options that have been provided on the command line.  For
# more specialized behavior, a customizations file can be provided as
# a second argument to the function call.
#
# In this customizations file, the following dereferences are allowed:
#
#  ${cur} --- the command-line word currently being parsed
#  ${prev} -- the previous word that was parsed
#
# as well as any of the Bash variables (e.g. COMP_WORDS, COMPREPLY, etc.)
#
# If a customizations file is provided, all automatically generated
# completions are still available--it is thus not necessary to define
# a customization for each program option.
##########################################################################

include(CMakeParseArguments)

function(cet_make_completions exec)
  set(output_file ${CMAKE_CURRENT_BINARY_DIR}/${exec}_completions)
  set(completion_comment "Generating bash completions for ${exec}")
  if(ARGV1)
    set(user_provided_completions ${ARGV1})
    set(completion_comment "${completion_comment} with customizations in ${user_provided_completions}")
  endif()
  add_custom_command(
    OUTPUT ${output_file}
    COMMAND ${cetbuildtools_BINDIR}/make_bash_completions ${output_file} ${exec} ${user_provided_completions}
    COMMENT ${completion_comment})
  add_custom_target(MakeCompletions_${exec} ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${exec}_completions)
  add_dependencies(MakeCompletions_${exec} ${exec})

  install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${exec}_completions DESTINATION ${${product}_bin_dir})
endfunction(cet_make_completions)
