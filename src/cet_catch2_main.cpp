// Tell Catch2 to provide a main() here.
#define CATCH_CONFIG_MAIN

// Indirection needed to ensure expansion of a.
#define CET_PP_STRINGIZE(a) CET_PP_STRINGIZE_I(a)
#define CET_PP_STRINGIZE_I(...) #__VA_ARGS__

// CET_CATCH2_INCLUDE_SUBDIR should be "catch" for Catch2 < 2.3.0,
// otherwise "catch2."
#include CET_PP_STRINGIZE(CET_CATCH2_INCLUDE_SUBDIR/catch.hpp)
