# ======================================================================
#  cetmodules
# ======================================================================

# use cmake 3.2 or later
cmake_minimum_required(VERSION 3.2)
# Project setup
project(cetmodules VERSION 0.03.00
                   LANGUAGES NONE)

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/Modules)

include(CetCMakeEnv)

# cetbuildtools has no architecture dependence
cet_cmake_env( noarch )

# cetmodules-config.cmake
include(CMakePackageConfigHelpers)

configure_package_config_file(
  ${PROJECT_NAME}-config.cmake.in
  ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
  INSTALL_DESTINATION . 
  )

write_basic_package_version_file(
  ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion
  )

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Config.cmake
              ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake
        DESTINATION . )

include(InstallLicense)
install_license()

add_subdirectory( Modules )
add_subdirectory( bin )

# packaging utility
include(UseCPackNoarch)
