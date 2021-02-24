#[================================================================[.rst:
#]================================================================]

find_package(art NO_MODULE)

if (art_FOUND AND art_VERSION VERSION_LESS 3.07.00)
  # Need to preempt old art_make(), simple_plugin(), etc.
  list(PREPEND CMAKE_MODULES_DIR ${CMAKE_CURRENT_LIST_DIR}/art)
  list(REMOVE_DUPLICATES CMAKE_MODULES_DIR)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(art CONFIG_MODE)
