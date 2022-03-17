include(CetGenerateSphinxDocs)

project_variable(SPHINX_DOC_PUBLISH_ROOT TYPE PATH
  DOCSTRING "destination directory for published HTML documentation"
  )
project_variable(SPHINX_DOC_PUBLISH_OLD_RELEASE TYPE BOOL
  DOCSTRING "Force overwrite of published documentation for a newer release of the same version"
  )
project_variable(SPHINX_DOC_PUBLISH_FORCE_NUMERIC TYPE BOOL
  DOCSTRING "Force use of version rather than branch even if we're in a git repository"
  )

# Default set of formats to generate.
if (NOT DEFINED CACHE{${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS_INIT})
  set(${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_FORMATS_INIT html man)
endif()

# Define information for substitution in conf.py.in.
set(PROJ_AUTHORS "Lynn Garren" "Patrick Gartung" "Chris Green" "scisoft-team <scisoft-team@fnal.gov>")
set(PROJ_NAME "${CETMODULES_CURRENT_PROJECT_NAME}")
set(PROJ_COPYRIGHT_START 2010)
set(PROJ_COPYRIGHT_OWNER "Fermi Research Alliance, LLC")
set(PROJ_VERSION ${CETMODULES_CURRENT_PROJECT_VERSION_MAJOR}.${CETMODULES_CURRENT_PROJECT_VERSION_MINOR})
set(PROJ_RELEASE ${CETMODULES_CURRENT_PROJECT_VERSION})

# Are we going with standard version/release, or using git branch/commit
# info?
if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_FORCE_NUMERIC
    OR NOT EXISTS ${PROJECT_SOURCE_DIR}/.git)
  set(is_numeric TRUE)
else()
  # Try to get the current branch for the version.
  execute_process(COMMAND git branch --show-current
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
    OUTPUT_VARIABLE current_branch
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if (NOT "${current_branch}" STREQUAL "")
    set(PROJ_VERSION "git-${current_branch}")
    # Try to get the current commit for the release.
    execute_process(COMMAND git rev-parse --short HEAD
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      OUTPUT_VARIABLE current_commit
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if (NOT "${current_commit}" STREQUAL "")
      set(PROJ_RELEASE "${PROJ_VERSION}-${current_commit}")
    else()
      set(PROJ_RELEASE "${PROJ_VERSION}")
    endif()
  endif()
endif()

# Generate the Sphinx configuration file.
configure_file(conf.py.in conf.py @ONLY)

# Set Sphinx verbosity-related options based on current CMake reporting
# level.
set(verbose_levels VERBOSE DEBUG TRACE)
set(quiet_levels ERROR WARNING NOTICE STATUS)
if (NOT CMAKE_MESSAGE_LOG_LEVEL OR CMAKE_MESSAGE_LOG_LEVEL IN_LIST quiet_levels)
  set(qv_arg QUIET)
elseif (CMAKE_MESSAGE_LOG_LEVEL IN_LIST verbose_levels)
  set(qv_arg VERBOSITY ${verbosity})
endif()

# Generate documentation for installation with this package.
cet_generate_sphinxdocs(${qv_arg} NITPICKY
  CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}"
  EXTRA_ARGS ${SPHINX_DOC_ARGS}
)

# If we've been told where to publish version-specific documentation, do
# so.
if (${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT)
  file(REAL_PATH "${${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_ROOT}"
    doc_publish_root BASE_DIRECTORY ${PROJECT_BINARY_DIR} EXPAND_TILDE)
  if (IS_DIRECTORY "${doc_publish_root}" AND
      EXISTS "${doc_publish_root}/version_switch.js")
    # Activate version switching.
    set(SPHINX_DOC_VSWITCH_ARGS -A versionswitch=1)
    # Read an existing versions.json file, if there is one.
    unset(versions_data)
    if (EXISTS "${doc_publish_root}/versions.json")
      file(READ "${doc_publish_root}/versions.json" versions_data)
    endif()
    if (NOT versions_data)
      set(versions_data "{}")
    endif()
    # How many versions are currently defined?
    string(JSON n_versions LENGTH "${versions_data}")
    set(is_latest ${is_numeric})
    # Analyze them.
    if (n_versions GREATER 0)
      math(EXPR last_idx "${n_versions} - 1")
      foreach (idx RANGE ${last_idx})
        string(JSON version MEMBER "${versions_data}" ${idx})
        if (version STREQUAL "latest")
          set(have_latest TRUE)
          continue()
        elseif (PROJ_VERSION STREQUAL version)
          set(have_version TRUE)
        endif()
        if (is_latest AND version MATCHES "^v([0-9]+(.[0-9]+)?)")
          # Are we still the latest version?
          cet_compare_versions(is_latest ${PROJ_VERSION} VERSION_GREATER_EQUAL ${version})
        endif()
      endforeach()
    endif()
    if (is_numeric)
      if (NOT is_latest)
        # We're publishing outdated documentation: label it as such.
        list(APPEND SPHINX_DOC_VSWITCH_ARGS -A outdated=1)
      endif()
      set(proj_dir "v${PROJ_VERSION}") # Destination directory.
      if (is_numeric
          AND NOT
          ${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_OLD_RELEASE
          AND EXISTS
          "${doc_publish_root}/${proj_dir}/_static/documentation_options.js")
        # We've already published documentation for this version: is
        # ours for an earlier release?
        file(READ
          "${doc_publish_root}/${proj_dir}/_static/documentation_options.js"
          doc_data) # Read the info for the generated documentation.
        # Extract the documentation release:
        if (doc_data MATCHES "\n[ \t]*VERSION[ \t\n]*:[ \t\n]*'([^']*)'")
          set(found_release "${CMAKE_MATCH_1}")
          cet_compare_versions(found_newer "${found_release}"
            VERSION_GREATER "${PROJ_RELEASE}")
          if (found_newer)
            # Skip publication of documentation for an older release.
            message(NOTICE "\
found already-published ${CETMODULES_CURRENT_PROJECT_NAME} \
documentation for newer release of version ${PROJ_VERSION} \
(${found_release} > ${PROJ_RELEASE}): will not overwrite (set \
${CETMODULES_CURRENT_PROJECT_NAME}_SPHINX_DOC_PUBLISH_OLD_RELEASE to \
force)\
")
            return()
          endif()
        endif()
      endif()
    else()
      set(proj_dir "${PROJ_VERSION}") # Destination directory.
    endif()
    # Ensure we have a line for this version in versions data.
    string(JSON versions_data SET "${versions_data}" "${proj_dir}"
      "\"${PROJ_VERSION}\"")
    if (is_latest)
      # Ensure we a line for "latest" in versions data.
      string(JSON versions_data SET "${versions_data}"
        "latest" "\"latest release\"")
    endif()
    # Write out the versions data as (possibly) amended by us.
    file(WRITE "${doc_publish_root}/versions.json" "${versions_data}\n")
    # Set the output directory accordingly.
    set(output_dir "${doc_publish_root}/${proj_dir}")
    set(clean_dirs "${output_dir}")
  else() # No versioning: publish at the top level.
    set(output_dir "${doc_publish_root}")
    file(GLOB clean_dirs CONFIGURE_DEPENDS "${doc_publish_root}/[^.]*"
      "${doc_publish_root}/.buildinfo")
  endif()
  # Generate the documentation for publication in the specified place.
  cet_generate_sphinxdocs(${qv_arg} NITPICKY NO_INSTALL
    CONF_DIR "${CMAKE_CURRENT_BINARY_DIR}"
    EXTRA_ARGS ${SPHINX_DOC_ARGS} ${SPHINX_DOC_VSWITCH_ARGS}
    OUTPUT_FORMATS html
    html_OUTPUT_DIR "${output_dir}"
    TARGET_STEM publish_cetmodules_${PROJ_VERSION}
    TARGETS_VAR published_target
    )
  # Grab the name of the target so we can tweak things slightly.
  list(FILTER published_target INCLUDE REGEX "_html$")
  # Remove any already-published documentation tree for this version
  # in its entirety prior to generated the updated documentation.
  add_custom_target(pre_clean_${published_target}
    COMMENT "\
Cleaning ${clean_dirs} prior to (re-)generation\
"
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${clean_dirs}
    VERBATIM COMMAND_EXPAND_LISTS
    )
  add_dependencies(${published_target} pre_clean_${published_target})
  if (is_latest) # Won't be set if we're not doing versioning.
    # Add the (re-)generation of the "latest" link to the generation
    # target.
    add_custom_command(TARGET ${published_target} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E rm -f "${doc_publish_root}/latest"
      COMMAND ${CMAKE_COMMAND} -E create_symlink
      "${proj_dir}" "${doc_publish_root}/latest"
      COMMENT "${published_target}: latest -> ${proj_dir}"
      )
  endif()
endif()
