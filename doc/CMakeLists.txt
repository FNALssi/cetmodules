include(CetGenerateSphinxDocs)

# Default set of formats to generate.
if (NOT DEFINED CACHE{${PROJECT_NAME}_SPHINX_DOC_FORMATS_INIT})
  set(${PROJECT_NAME}_SPHINX_DOC_FORMATS_INIT html man)
endif()

# Define information for substitution in conf.py.in.
set(PROJ_AUTHORS "Lynn Garren" "Patrick Gartung" "Chris Green" "scisoft-team <scisoft-team@fnal.gov>")
set(PROJ_NAME "${PROJECT_NAME}")
set(PROJ_COPYRIGHT_START 2010)
set(PROJ_COPYRIGHT_OWNER "Fermi Research Alliance, LLC")
set(PROJ_VERSION ${CETMODULES_CURRENT_PROJECT_VERSION_MAJOR}.${CETMODULES_CURRENT_PROJECT_VERSION_MINOR})
set(PROJ_RELEASE ${CETMODULES_CURRENT_PROJECT_VERSION})

# Generate the Sphinx configuration file.
configure_file(conf.py.in conf.py @ONLY)

set(verbose_levels VERBOSE DEBUG TRACE)
set(quiet_levels ERROR WARNING NOTICE STATUS)
if (NOT CMAKE_MESSAGE_LOG_LEVEL OR CMAKE_MESSAGE_LOG_LEVEL IN_LIST quiet_levels)
  set(qv_arg QUIET)
elseif (CMAKE_MESSAGE_LOG_LEVEL IN_LIST verbose_levels)
  set(qv_arg VERBOSITY ${verbosity})
endif()

# Use it to generate our documentation.
cet_generate_sphinxdocs(${qv_arg} NITPICKY
  CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  EXTRA_ARGS # -Dsuppress_warnings=*
  # -W --keep-going
)
