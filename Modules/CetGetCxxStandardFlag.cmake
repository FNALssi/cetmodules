# Function to reconstruct a useful C++ standard flag from the
# appropriate CMake variables. Ideally this would be a generator
# expression for the current target.
function(cet_get_cxx_standard_flag OUTPUT_VAR)
  set(tmp_flag "-std=")
  if (CMAKE_CXX_STANDARD)
    if (CMAKE_CXX_EXTENSIONS)
      string(APPEND tmp_flag "gnu")
    else()
      string(APPEND tmp_flag "cxx")
    endif()
    string(APPEND tmp_flag "${CMAKE_CXX_STANDARD}")
  endif()
  set(${OUTPUT_VAR} ${tmp_flag} PARENT_SCOPE)
endfunction()
