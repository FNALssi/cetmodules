project_variable(CATCH2_MAIN CONFIG src/cet_catch2_main.cpp)
cet_copy(${CMAKE_CURRENT_SOURCE_DIR}/cet_catch2_main.cpp DESTINATION .)
install(FILES cet_catch2_main.cpp DESTINATION src)
