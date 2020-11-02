project_variable(TOOLS_DIR tools CONFIG
  DOCSTRING "Location of useful scripts and files for ${PROJECT_NAME}")

cet_script(DESTINATION ${cetmodules_TOOLS_DIR}
  migrate)
