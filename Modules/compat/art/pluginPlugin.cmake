include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(BasicPlugin)

function(plugin_plugin NAME)
  basic_plugin(${NAME} "plugin" NOP ${ARGN}
    LIBRARIES PLUGIN art::Framework_Core)
endfunction()

cmake_policy(POP)
