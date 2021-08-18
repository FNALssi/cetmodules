set(cetmodules_bootstrap_version ${cetmodules_VERSION})
set(cetbuildtools_bootstrap_version ${cetmodules_MIN_CETBUILDTOOLS_VERSION})
foreach(pkg IN ITEMS modules buildtools)
  set(bootstrap_package cet${pkg})
  set(bootstrap_version ${${bootstrap_package}_bootstrap_version})
  configure_file(Bootstrap.cmake.in BootstrapCet${pkg}.cmake @ONLY)
  list(APPEND generated_modules
    "${CMAKE_CURRENT_BINARY_DIR}/BootstrapCet${pkg}.cmake")
endforeach()

file(READ "${CMAKE_ROOT}/Modules/WriteBasicConfigVersionFile.cmake" content)
string(REPLACE "WRITE_BASIC_CONFIG_VERSION_FILE"
  "cet_write_package_version_file" content "${content}")
string(REPLACE "\${CMAKE_ROOT}/Modules/BasicConfigVersion"
  "\${cetmodules_CONFIG_DIR}/CetConfigVersion"
  content "${content}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/CetWritePackageVersionFile.cmake" "${content}")
list(APPEND generated_modules
  "${CMAKE_CURRENT_BINARY_DIR}/CetWritePackageVersionFile.cmake")

install(DIRECTORY ./ DESTINATION Modules
  FILES_MATCHING PATTERN "*.cmake" PATTERN "[.#]*.cmake" EXCLUDE)
install(FILES ${generated_modules} DESTINATION Modules)

file(COPY . DESTINATION .
  FILES_MATCHING PATTERN "*.cmake" PATTERN "[.#]*.cmake" EXCLUDE)

########################################################################
# Generate plugin builds for compatibility.
set(dest_subdir Modules/compat/art)

# Function to reduce duplication when generating the art suite plugin
# builders for compatibility,
function(make_simple_builder NAME)
  # Drop namespacing to ascertain target name (art internal convention
  # only).
  string(REGEX REPLACE "^.*::" "" TGT "${NAME}")
  list(POP_FRONT ARGN kw)
  if (kw STREQUAL "BASE")
    list(POP_FRONT ARGN BASE)
  elseif (TGT MATCHES "([A-Z][a-z]+)$")
    string(TOLOWER "art::${CMAKE_MATCH_1}" BASE)
  else()
    message(FATAL_ERROR "unable to deduce BASE: specify explicitly")
  endif()
  string(REGEX REPLACE "^(.+)$"
    "$<$<TARGET_EXISTS:art_plugin_types::\\1>:art_plugin_types::\\1>"
    TGT "${TGT}")
  cet_make_plugin_builder(${NAME} ${BASE} ${dest_subdir} ${ARGN} LIBRARIES
    REG ${TGT} NOP)
endfunction()

# Generate plugin builders for compatibility for art suites < v3_10_00.
include(BasicPlugin)

make_simple_builder(art::DRISISource BASE art::InputSource LIBRARIES CONDITIONAL art::Framework_Core)
make_simple_builder(art::EmptyEventTimestampPlugin)
make_simple_builder(art::FileCatalogMetadataPlugin)
make_simple_builder(art::FileDeliveryService)
make_simple_builder(art::FileTransferService)
make_simple_builder(art::InputSource)
make_simple_builder(art::MixFilter BASE art::module)
make_simple_builder(art::Output BASE art::module)
make_simple_builder(art::ProducingService)
make_simple_builder(art::ProvenanceDumperOutput BASE art::Output)
make_simple_builder(art::ResultsProducer BASE art::plugin)
make_simple_builder(art::SourceT BASE art::source)

foreach (prefix ED Replicated Shared "")
  if (prefix STREQUAL "")
    set(dir detail/)
  else()
    unset(dir)
  endif()
  foreach (type Analyzer Filter Producer)
    cet_make_library(LIBRARY_NAME ${prefix}${type} INTERFACE
      EXPORT_SET PluginTypes SOURCE ${dir}${prefix}${type}.h)
    make_simple_builder(art::${prefix}${type} BASE art::module)
  endforeach()
endforeach()

# Generate a module that includes all the art plugin types, including
# the bespoke top-level types.
list(APPEND CETMODULES_PLUGIN_BUILDERS_PROJECT_${CETMODULES_CURRENT_PROJECT_NAME}
  art::plugin art::module art::service art::source art::tool)
cet_collect_plugin_builders(${dest_subdir} ArtPlugins)

# messagefacility types:
make_simple_builder(mfPlugin BASE mfPlugin)
make_simple_builder(mfStatsPlugin BASE mfStatsPlugin)

# Compatible convenience wrapper module for messagefacility plugin types
# (list was reset by previous call to cet_collect_plugin_builders().
cet_collect_plugin_builders(${dest_subdir} MessagefacilityPlugins)
