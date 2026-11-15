# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# A template (templates/, not ports/): tools/port_bump.py moves it into ports/
# on the first Termite release that installs core/ as the CMake package termite-core
# (swarm-routing/Termite#135), writing the version and the SHA512 of that release's asset.
# core/ alone, swarm-core from its port: find_package(termite-core CONFIG REQUIRED),
# target termite::core.
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/Termite/releases/download/v${VERSION}/termite-${VERSION}.tar.gz"
    FILENAME "termite-${VERSION}.tar.gz"
    SHA512 0
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/core"
    OPTIONS
        -DTERMITE_CORE_TESTS=OFF
        -DTERMITE_CORE_SWARM_CORE_FROM_PACKAGE=ON
        -DTERMITE_CORE_INSTALL=ON
        -DTERMITE_CORE_VERSION=${VERSION}
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME termite-core CONFIG_PATH lib/cmake/termite-core)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/doc")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/core/LICENSE")
