include(CetGenerateSphinxDocs)

# Set Sphinx verbosity-related options based on current CMake reporting
# level.
set(verbose_levels VERBOSE DEBUG TRACE)
set(quiet_levels ERROR WARNING NOTICE STATUS)
if (NOT CMAKE_MESSAGE_LOG_LEVEL OR CMAKE_MESSAGE_LOG_LEVEL IN_LIST quiet_levels)
  set(qv_arg QUIET)
elseif (CMAKE_MESSAGE_LOG_LEVEL IN_LIST verbose_levels)
  list(FIND verbose_levels ${CMAKE_MESSAGE_LOG_LEVEL} default_verbosity)
  math(EXPR verbosity ${default_verbosity} + 1)
  set(qv_arg VERBOSITY ${default_verbosity})
endif()

project_variable(SPHINX_DOC_PUBLISH_ROOT TYPE PATH
  DOCSTRING "destination directory for published HTML documentation"
)

project_variable(SPHINX_DOC_PUBLISH_OLD_RELEASE TYPE BOOL
  DOCSTRING "force overwrite of published documentation for a newer release of the same version"
)

project_variable(SPHINX_DOC_PUBLISH_FORCE_NUMERIC TYPE BOOL
  DOCSTRING "force use of version rather than branch even if we're in a git repository"
)

project_variable(SPHINX_DOC_PUBLISH_VERSION_BRANCH TYPE STRING
  DOCSTRING "specify branch name to be used in PROJ_VERSION (when applicable) instead of using git branch --show-current"
)

project_variable(SPHINX_DOC_EXTRA_ARGS TYPE STRING
  DOCSTRING "extra arguments to sphinx-build")
foreach (fmt html man)
  project_variable(SPHINX_DOC_${fmt}_EXTRA_ARGS TYPE STRING
    DOCSTRING "extra arguments to sphinx-build for output format ${fmt}")
endforeach()

# Define information for substitution in conf.py.in.
set(PROJ_AUTHORS "Lynn Garren" "Patrick Gartung" "Chris Green" "scisoft-team <scisoft-team@fnal.gov>")
set(PROJ_NAME "Cetmodules")
set(PROJ_COPYRIGHT_START 2010)
set(PROJ_COPYRIGHT_OWNER "Fermi Research Alliance, LLC")

# Are we going with standard version/release, or using git branch/commit
# info?
if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_FORCE_NUMERIC
    OR NOT EXISTS ${PROJECT_SOURCE_DIR}/.git)
  set(PROJ_VERSION ${CETMODULES_CURRENT_PROJECT_VERSION_MAJOR}.${CETMODULES_CURRENT_PROJECT_VERSION_MINOR})
  set(PROJ_RELEASE ${CETMODULES_CURRENT_PROJECT_VERSION})
else()
  if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_VERSION_BRANCH)
    set(current_branch "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_VERSION_BRANCH}")
  else()
    # Try to get the current branch for the version.
    execute_process(COMMAND git branch --show-current
      COMMAND_ERROR_IS_FATAL ANY
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      OUTPUT_VARIABLE current_branch
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  endif()
  set(PROJ_VERSION "git-${current_branch}")
  # Try to get the current commit for the release.
  execute_process(COMMAND git rev-parse --short HEAD
    COMMAND_ERROR_IS_FATAL ANY
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    OUTPUT_VARIABLE current_commit
    OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(PROJ_RELEASE "${PROJ_VERSION}-${current_commit}")
endif()

set(WANT_UNIX_MAN_PAGES "False")

# Generate the reference documentation for publication in the specified place.
if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT)
  set(WANT_VERSION_SWITCH "True")
  configure_file(reference/conf.py.in "reference/conf.py" @ONLY)
  file(REAL_PATH "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT}"
    ${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT
    BASE_DIRECTORY ${PROJECT_BINARY_DIR} EXPAND_TILDE)
  if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_OLD_RELEASE)
    set(PUBLISH_OLD_RELEASE PUBLISH_OLD_RELEASE)
  else()
    unset(PUBLISH_OLD_RELEASE)
  endif()
  configure_file(version_switch.js
    "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT}/version_switch.js"
    COPYONLY
    )
  cet_publish_sphinx_html(
    "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT}"
    ${PROJ_VERSION}
    ${PUBLISH_OLD_RELEASE}
    ${qv_arg}
    NITPICKY
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/reference"
    CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}/reference"
    EXTRA_ARGS ${cetmodules_SPHINX_DOC_EXTRA_ARGS}
    html_EXTRA_ARGS ${cetmodules_SPHINX_DOC_html_EXTRA_ARGS}
  )
  configure_file(landing/conf.py.in "landing/conf.py" @ONLY)
  cet_generate_sphinx_docs(${qv_arg}
    NITPICKY
    TARGET_STEM publish_${CETMODULES_CURRENT_PROJECT_NAME}_landing
    html_OUTPUT_DIR
    "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT}"
    html_NO_DELETE_OUTPUT_DIR
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/landing"
    CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}/landing"
    EXTRA_ARGS ${cetmodules_SPHINX_DOC_EXTRA_ARGS}
    html_EXTRA_ARGS ${cetmodules_SPHINX_DOC_html_EXTRA_ARGS}
    )
endif()

set(WANT_VERSION_SWITCH "False")
configure_file(reference/conf.py.in "conf.py" @ONLY)

# Generate documentation for installation with this package.
cet_generate_sphinx_docs(${qv_arg}
  NITPICKY
  OUTPUT_FORMATS html
  SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/reference"
  CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  EXTRA_ARGS ${cetmodules_SPHINX_DOC_EXTRA_ARGS}
  html_EXTRA_ARGS ${cetmodules_SPHINX_DOC_html_EXTRA_ARGS}
)

set(WANT_UNIX_MAN_PAGES "True")
configure_file(reference/conf.py.in "man-conf/conf.py" @ONLY)
cet_generate_sphinx_docs(${qv_arg}
  NITPICKY
  OUTPUT_FORMATS man
  SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/reference"
  CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}/man-conf"
  EXTRA_ARGS ${cetmodules_SPHINX_DOC_EXTRA_ARGS}
  man_EXTRA_ARGS ${cetmodules_SPHINX_DOC_man_EXTRA_ARGS}
)
