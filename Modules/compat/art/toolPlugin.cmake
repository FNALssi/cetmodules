include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(BasicPlugin)

function(tool_plugin NAME)
  set(deps art_plugin_support::tool_macros)
  if (NOT TARGET ${deps})
    set(deps
      art_Utilities
      fhiclcpp
      cetlib
      cetlib_except
      Boost::filesystem)
  endif()
  basic_plugin(${NAME} "tool" NOP ${ARGN}
    LIBRARIES PLUGIN "${deps}")
endfunction()

cmake_policy(POP)
