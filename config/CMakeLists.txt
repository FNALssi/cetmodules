include(ProjectVariable)

# Modules will need this when they're being used by other packages.
project_variable(CONFIG_DIR config CONFIG
  DOCSTRING "Directory containing cetmodules' fragment templates for generating CMake config files")

set(install_files
  package-config.cmake.preamble.in
  package-config.cmake.init.in
  package-config.cmake.bottom.in
  )

foreach (compat IN ITEMS AnyNewer Exact SameMajor SameMinor)
  list(APPEND install_files CetConfigVersion-${compat}Version.cmake.in)
endforeach()

install(FILES ${install_files}
  DESTINATION ${${PROJECT_NAME}_CONFIG_DIR})
