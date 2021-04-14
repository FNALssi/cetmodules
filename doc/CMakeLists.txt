include(CetGenerateSphinxDocs)

# Default set of formats to generate.
if (NOT DEFINED CACHE{${PROJECT_NAME}_SPHINX_DOC_FORMATS_INIT})
  set(${PROJECT_NAME}_SPHINX_DOC_FORMATS_INIT html man)
endif()

# Define information for substitution in conf.py.in.
set(PROJ_AUTHORS "Lynn Garren" "Chris Green" "scisoft-team <scisoft-team@fnal.gov>")
set(PROJ_NAME "${PROJECT_NAME}")
set(PROJ_COPYRIGHT_START 2010)
set(PROJ_COPYRIGHT_OWNER "Fermi Research Alliance, LLC")

# Generate the Sphinx configuration file.
configure_file(conf.py.in conf.py @ONLY)

set(verbose_levels NONE VERBOSE DEBUG TRACE)
set(quiet_levels ERROR WARNING NOTICE)
list(FIND verbose_levels "${CMAKE_MESSAGE_LOG_LEVEL}" verbosity)
if (verbosity GREATER 0)
  set(qv_arg VERBOSITY ${verbosity})
elseif (CMAKE_MESSAGE_LOG_LEVEL IN_LIST quiet_levels)
  set(qv_arg QUIET)
endif()

# Use it to generate our documentation.
cet_generate_sphinxdocs(VERBOSITY 2 NITPICKY
  CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  EXTRA_ARGS # -Dsuppress_warnings=*
  # -W --keep-going
)

find_package(CppUnit QUIET)
