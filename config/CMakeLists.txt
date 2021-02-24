include(ProjectVariable)

# Modules will need this when they're being used by other packages.
project_variable(CONFIG_DIR config CONFIG
  DOCSTRING "Directory containing cetmodules' fragment templates for generating CMake config files")

install(FILES
  package-config.cmake.preamble.in
  package-config.cmake.init.in
  package-config.cmake.bottom.in
  DESTINATION ${${PROJECT_NAME}_CONFIG_DIR})

add_subdirectory(ups)
