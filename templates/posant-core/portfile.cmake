# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# A template (templates/, not ports/): tools/port_bump.py moves it into ports/
# on the first POSANT release (its core/ installs the CMake package posant-core
# with POSANT_CORE_INSTALL=ON), writing the version and the SHA512 of that release's asset.
# core/ alone, swarm-core from its port: find_package(posant-core CONFIG REQUIRED),
# target posant::core.
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/POSANT/releases/download/v${VERSION}/posant-${VERSION}.tar.gz"
    FILENAME "posant-${VERSION}.tar.gz"
    SHA512 0
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/core"
    OPTIONS
        -DPOSANT_CORE_TESTS=OFF
        -DPOSANT_CORE_SWARM_CORE_FROM_PACKAGE=ON
        -DPOSANT_CORE_INSTALL=ON
        -DPOSANT_CORE_VERSION=${VERSION}
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME posant-core CONFIG_PATH lib/cmake/posant-core)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/doc")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/core/LICENSE")
