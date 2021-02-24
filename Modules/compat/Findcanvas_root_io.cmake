#[================================================================[.rst:
#]================================================================]

find_package(canvas_root_io NO_MODULE)

if (canvas_root_io_FOUND AND canvas_root_io_VERSION VERSION_LESS 1.08.00)
  # Need to preempt old art_dictionary().
  list(PREPEND CMAKE_MODULES_DIR ${CMAKE_CURRENT_LIST_DIR}/art)
  list(REMOVE_DUPLICATES CMAKE_MODULES_DIR)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(canvas_root_io CONFIG_MODE)
