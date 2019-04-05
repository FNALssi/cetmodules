########################################################################
# Construct the archive with the structure we need.
########################################################################

# Create product tree.
file(MAKE_DIRECTORY "${CPACK_TOPLEVEL_DIRECTORY}/${UPS_PRODUCT_SUBDIR}")

# Move version directory in to the right place in the tree. We do this
# first because the best way to refer to it is by using a variable
# referring to the directory we're going to move next.
file(RENAME "${CPACK_TEMPORARY_DIRECTORY}/${UPS_PRODUCT_VERSION_SUBDIR}"
  "${CPACK_TOPLEVEL_DIRECTORY}/${UPS_PRODUCT_NAME}/${UPS_PRODUCT_VERSION_DIRNAME}")
# Move the main installation area into the right place in the tree.
file(RENAME "${CPACK_TEMPORARY_DIRECTORY}" "${CPACK_TOPLEVEL_DIRECTORY}/${UPS_PRODUCT_SUBDIR}")
# Construct the archive.
execute_process(COMMAND tar -C "${CPACK_TOPLEVEL_DIRECTORY}" -jcf
  "${CPACK_PACKAGE_FILE_NAME}.tar.bz2" "${UPS_PRODUCT_NAME}"
  RESULTS_VARIABLE tar_status)
# Report.
if (tar_status EQUAL 0)
  message("Unified UPS-format tar archive ${UPS_TAR_DIR}/${CPACK_PACKAGE_FILE_NAME}.tar.bz2 generated.")
else()
  message(FATAL_ERROR "Unable to create unified UPS-format tar archive ${UPS_TAR_DIR}/${CPACK_PACKAGE_FILE_NAME}.tar.bz2.")
endif()
