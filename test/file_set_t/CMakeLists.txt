cmake_minimum_required(VERSION 3.23)
project(file_set_t)

find_package(cetmodules REQUIRED)

cet_make_library(
  LIBRARY_NAME my_lib
  SOURCE my_lib.cpp
  FILE_SETS "FILE_SET HEADERS TYPE HEADERS FILES my_header.hpp"
)

cet_make_exec(
  NAME my_exec
  SOURCE my_exec.cpp
  LIBRARIES my_lib
  FILE_SETS "FILE_SET HEADERS TYPE HEADERS FILES my_header.hpp"
)
