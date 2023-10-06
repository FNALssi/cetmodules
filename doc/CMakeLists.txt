include(CetGenerateSphinxDocs)

function(_generate_reference)
  set(source_root "${CMAKE_CURRENT_BINARY_DIR}/gen/install")
  set(doc_root "${source_root}/doc")
  file(MAKE_DIRECTORY "${doc_root}/reference")
  cet_copy("${CMAKE_CURRENT_SOURCE_DIR}/cetmodules-common.rst"
    DESTINATION "${doc_root}"
    TARGET_VAR gen_common)
  _symlink_sourcedirs_to("${source_root}")
  _symlink_reference_to("${doc_root}/reference")

  file(WRITE "${doc_root}/reference/index.rst"
    "\
${LANDING_TOP}

Reference
=========

Command-Line Tools
------------------

${REF_TOOLS}

Reference Manuals
-----------------

${REF_MANUALS}

Helpers and Legacy Tools
------------------------

${REF_HELPERS}

${LANDING_BOTTOM}

.. only:: html

   Index and Search
   ================

   * :ref:`genindex`
   * :ref:`search`
")
  # Generate documentation for installation with this package.
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/reference-conf.py.in" ref_conf)
  string(CONFIGURE "\
${COMMON_CONF}

${ref_conf}
" ref_conf @ONLY ESCAPE_QUOTES)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/conf.py" "${ref_conf}")

  cet_generate_sphinx_docs(${qv_arg}
    NITPICKY
    OUTPUT_FORMATS html
    SOURCE_DIR "${doc_root}/reference"
    CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    EXTRA_ARGS ${cetmodules_SPHINX_DOC_EXTRA_ARGS}
    html_EXTRA_ARGS ${cetmodules_SPHINX_DOC_html_EXTRA_ARGS}
    TARGETS_VAR html_targets
  )

  set(WANT_UNIX_MAN_PAGES "True")
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/reference-conf.py.in" ref_conf)
  string(CONFIGURE "\
${COMMON_CONF}

${ref_conf}
" ref_conf @ONLY ESCAPE_QUOTES)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/man-conf/conf.py" "${ref_conf}")
  cet_generate_sphinx_docs(${qv_arg}
    NITPICKY
    OUTPUT_FORMATS man
    SOURCE_DIR "${doc_root}/reference"
    CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}/man-conf"
    EXTRA_ARGS ${cetmodules_SPHINX_DOC_EXTRA_ARGS}
    man_EXTRA_ARGS ${cetmodules_SPHINX_DOC_man_EXTRA_ARGS}
    TARGETS_VAR man_targets
  )
  foreach (target IN LISTS html_targets man_targets)
    add_dependencies(${target} ${gen_common})
  endforeach()
endfunction()

function(_publish_to_root)
  set(WANT_VERSION_SWITCH "True")

  set(source_root "${CMAKE_CURRENT_BINARY_DIR}/gen/publish")
  set(doc_root "${source_root}/doc")
  file(MAKE_DIRECTORY
    "${doc_root}/landing"
    "${doc_root}/reference"
  )
  cet_copy("${CMAKE_CURRENT_SOURCE_DIR}/cetmodules-common.rst"
    DESTINATION "${doc_root}"
    TARGET_VAR publish_common)
  _symlink_sourcedirs_to("${source_root}")
  _symlink_reference_to("${doc_root}/reference")
  file(WRITE "${doc_root}/reference/index.rst"
    "\
#######################
Reference Documentation
#######################

Command-Line Tools
==================

${REF_TOOLS}

Reference Manuals
=================

${REF_MANUALS}

Helpers and Legacy Tools
========================

${REF_HELPERS}


.. only:: html

   Index and Search
   ================

   * :ref:`genindex`
   * :ref:`search`
")
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/reference-conf.py.in" ref_conf)
  string(CONFIGURE "\
${COMMON_CONF}

${ref_conf}
" ref_conf @ONLY ESCAPE_QUOTES)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/reference/conf.py" "${ref_conf}")
  file(REAL_PATH "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT}"
    ${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT
    BASE_DIRECTORY ${PROJECT_BINARY_DIR} EXPAND_TILDE)
  if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_OLD_RELEASE)
    set(PUBLISH_OLD_RELEASE PUBLISH_OLD_RELEASE)
  else()
    unset(PUBLISH_OLD_RELEASE)
  endif()
  cet_publish_sphinx_html(
    "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT}"
    ${PROJ_VERSION}
    ${PUBLISH_OLD_RELEASE}
    ${qv_arg}
    NITPICKY
    SOURCE_DIR "${doc_root}/reference"
    CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}/reference"
    EXTRA_ARGS ${cetmodules_SPHINX_DOC_EXTRA_ARGS}
    html_EXTRA_ARGS ${cetmodules_SPHINX_DOC_html_EXTRA_ARGS}
    TARGETS_VAR landing_targets
  )
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/landing-reference.rst" landing_ref)
  file(WRITE "${doc_root}/landing/index.rst"
    "\
${LANDING_TOP}

${landing_ref}

${LANDING_BOTTOM}
")
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/landing-conf.py.in" landing_conf)
  string(CONFIGURE "\
${COMMON_CONF}

${landing_conf}
" landing_conf @ONLY ESCAPE_QUOTES)
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/landing/conf.py" "${landing_conf}")
  cet_generate_sphinx_docs(${qv_arg}
    NITPICKY
    TARGET_STEM publish_${CETMODULES_CURRENT_PROJECT_NAME}_landing
    html_OUTPUT_DIR
    "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT}"
    html_NO_DELETE_OUTPUT_DIR
    SOURCE_DIR "${doc_root}/landing"
    CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}/landing"
    EXTRA_ARGS ${cetmodules_SPHINX_DOC_EXTRA_ARGS}
    html_EXTRA_ARGS ${cetmodules_SPHINX_DOC_html_EXTRA_ARGS}
    TARGETS_VAR html_targets
  )
  foreach (target IN LISTS landing_targets html_targets)
    add_dependencies(${target} ${publish_common})
  endforeach()
endfunction()

# Are we going with standard version/release, or using git branch/commit
# info?
function(_set_version_release)
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
  set(PROJ_VERSION "${PROJ_VERSION}" PARENT_SCOPE)
  set(PROJ_RELEASE "${PROJ_RELEASE}" PARENT_SCOPE)
  return()
endfunction()

function(_symlink_sourcedirs_to DEST)
  foreach(item IN ITEMS LICENSE Modules)
    file(CREATE_LINK
      "${PROJECT_SOURCE_DIR}/${item}"
      "${DEST}/${item}"
      SYMBOLIC)
  endforeach()
endfunction()

function(_symlink_reference_to DEST)
  foreach(item IN ITEMS
      envvar
      manual
      module
      tgt_prop
      variable
    )
    file(CREATE_LINK
      "${PROJECT_SOURCE_DIR}/doc/reference/${item}"
      "${DEST}/${item}"
      SYMBOLIC)
  endforeach()
endfunction()
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

_set_version_release()

set(WANT_UNIX_MAN_PAGES "False")
set(WANT_VERSION_SWITCH "False")

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/common-conf.py.in" COMMON_CONF)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/landing-top.rst" LANDING_TOP)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/landing-bottom.rst" LANDING_BOTTOM)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/reference-command-line-tools.rst" REF_TOOLS)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/reference-manuals.rst" REF_MANUALS)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/reference-helpers-etc.rst" REF_HELPERS)

if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT)
  _publish_to_root()
endif()

_generate_reference()

