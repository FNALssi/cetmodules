include(CetGenerateSphinxDocs)

# Define information for substitution in conf.py.in.
string(JOIN "." PROJECT_RELEASE ${PROJECT_MAJOR_VERSION} ${PROJECT_MINOR_VERSION})
set(PROJECT_AUTHORS "Lynn Garren" "Chris Green" "scisoft-team <scisoft-team@fnal.gov>")

# Generate the Sphinx configuration file.
configure_file(conf.py.in conf.py @ONLY)

# Use it to generate our documentation.
cet_generate_sphinxdocs(NITPICKY VERBOSE CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}")
