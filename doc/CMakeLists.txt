include(CetGenerateSphinxDocs)
configure_file(conf.py.in conf.py @ONLY)

cet_generate_sphinxdocs(VERBOSE CONF_DIR ${CMAKE_CURRENT_BINARY_DIR})
