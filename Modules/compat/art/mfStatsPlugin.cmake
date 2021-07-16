include_guard(DIRECTORY)

cmake_policy(PUSH)
cmake_minimum_required(VERSION 3.18.2 FATAL_ERROR)

include(BasicPlugin)

macro(mfStatsPlugin NAME)
  basic_plugin(${NAME} mfStatsPlugin ${ARGN}
    LIBRARIES REG art_plugin_types::mfStatsPlugin)
endmacro()

cmake_policy(POP)
