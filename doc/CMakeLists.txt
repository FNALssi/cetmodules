include(CetGenerateSphinxDocs)

find_package(M4 REQUIRED)

function(_generate_cet_install_opts_inc)
  set(cet_install_opts_dir "${doc_root}/reference/_cet_install_opts")

  add_custom_command(OUTPUT "${doc_root}/reference/opts-inc.rst"
    COMMAND M4::M4
    -Dm4src="${doc_root}/reference/_cet_install_opts"
    "${CMAKE_CURRENT_SOURCE_DIR}/reference/opts-inc.rst.m4"
    > "${doc_root}/reference/opts-inc.rst"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/reference/opts-inc.rst.m4"
    "${cet_install_opts_dir}/BASENAME_EXCLUDES.rst"
    "${cet_install_opts_dir}/DESTINATION.rst"
    "${cet_install_opts_dir}/DEST_VAR.rst"
    "${cet_install_opts_dir}/EXCLUDES.rst"
    "${cet_install_opts_dir}/EXTRAS.rst"
    "${cet_install_opts_dir}/LIST.rst"
    "${cet_install_opts_dir}/PROGRAMS.rst"
    "${cet_install_opts_dir}/SUBDIRNAME.rst"
    "${cet_install_opts_dir}/SUBDIRS.rst"
    VERBATIM
    COMMENT "Generating ${doc_root}/reference/opts-inc.rst with m4"
  )
endfunction()

function(_generate_reference)
  set(source_root "${CMAKE_CURRENT_BINARY_DIR}/gen/install")
  set(doc_root "${source_root}/doc")
  file(MAKE_DIRECTORY "${doc_root}/reference")
  cet_copy("${CMAKE_CURRENT_SOURCE_DIR}/cetmodules-common.rst"
    DESTINATION "${doc_root}")
  _symlink_sourcedirs_to("${source_root}")
  _symlink_reference_to("${doc_root}/reference")

  add_custom_command(OUTPUT "${doc_root}/reference/index.rst"
    COMMAND M4::M4
    -DLANDING_TOP="${LANDING_TOP}"
    -DREF_TOOLS="${REF_TOOLS}"
    -DREF_MANUALS="${REF_MANUALS}"
    -DREF_HELPERS="${REF_HELPERS}"
    -DLANDING_BOTTOM="${LANDING_BOTTOM}"
    "${CMAKE_CURRENT_SOURCE_DIR}/reference-index.rst.m4"
    > "${doc_root}/reference/index.rst"
    DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/reference-index.rst.m4"
    "${LANDING_TOP}"
    "${REF_TOOLS}"
    "${REF_MANUALS}"
    "${REF_HELPERS}"
    "${LANDING_BOTTOM}"
    VERBATIM
    COMMENT "Generating ${doc_root}/reference/index.rst with m4"
  )

  _generate_cet_install_opts_inc()

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
    DEPENDS "${doc_root}/reference/index.rst"
    "${doc_root}/cetmodules-common.rst"
    "${doc_root}/reference/opts-inc.rst"
    TARGETS_VAR reference_html_target
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
    DEPENDS "${doc_root}/reference/index.rst" "${doc_root}/cetmodules-common.rst"
    TARGETS_VAR reference_man_target
  )
    add_custom_target(doc-cetmodules-reference)
    add_dependencies(doc-cetmodules-reference ${reference_html_target} ${reference_man_target})
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
    DESTINATION "${doc_root}")
  _symlink_sourcedirs_to("${source_root}")
  _symlink_reference_to("${doc_root}/reference")
  add_custom_command(OUTPUT "${doc_root}/reference/index.rst"
    COMMAND M4::M4
    -DREF_TOOLS="${REF_TOOLS}"
    -DREF_MANUALS="${REF_MANUALS}"
    -DREF_HELPERS="${REF_HELPERS}"
    "${CMAKE_CURRENT_SOURCE_DIR}/publish-reference-index.rst.m4"
    > "${doc_root}/reference/index.rst"
    DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/publish-reference-index.rst.m4"
    "${REF_TOOLS}"
    "${REF_MANUALS}"
    "${REF_HELPERS}"
    VERBATIM
    COMMENT "Generating ${doc_root}/reference/index.rst with m4"
  )

  _generate_cet_install_opts_inc()

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
    DEPENDS "${doc_root}/reference/index.rst"
    "${doc_root}/cetmodules-common.rst"
    "${doc_root}/reference/opts-inc.rst"
    TARGETS_VAR publish_ref_target
  )
  add_custom_command(OUTPUT "${doc_root}/landing/index.rst"
    COMMAND M4::M4
    -DLANDING_TOP="${LANDING_TOP}"
    -DLANDING_REF="${LANDING_REF}"
    -DLANDING_BOTTOM="${LANDING_BOTTOM}"
    "${CMAKE_CURRENT_SOURCE_DIR}/landing-index.rst.m4"
    > "${doc_root}/landing/index.rst"
    DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/landing-index.rst.m4"
    "${LANDING_TOP}"
    "${LANDING_REF}"
    "${LANDING_BOTTOM}"
    VERBATIM
    COMMENT "Generating ${doc_root}/landing/index.rst with m4"
  )
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
    DEPENDS "${doc_root}/landing/index.rst" "${doc_root}/cetmodules-common.rst"
    TARGETS_VAR publish_landing_target
  )

  add_custom_target(doc-cetmodules-publish)
  add_dependencies(doc-cetmodules-publish ${publish_ref_target} ${publish_landing_target})
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
      _cet_install_opts
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
set(LANDING_TOP "${CMAKE_CURRENT_SOURCE_DIR}/landing-top.rst")
set(LANDING_REF "${CMAKE_CURRENT_SOURCE_DIR}/landing-reference.rst")
set(LANDING_BOTTOM "${CMAKE_CURRENT_SOURCE_DIR}/landing-bottom.rst")
set(REF_TOOLS "${CMAKE_CURRENT_SOURCE_DIR}/reference-command-line-tools.rst")
set(REF_MANUALS "${CMAKE_CURRENT_SOURCE_DIR}/reference-manuals.rst")
set(REF_HELPERS "${CMAKE_CURRENT_SOURCE_DIR}/reference-helpers-etc.rst")

if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT)
  _publish_to_root()
endif()

_generate_reference()

