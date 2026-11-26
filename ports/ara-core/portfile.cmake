# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# A template (templates/, not ports/): tools/port_bump.py moves it into ports/
# on the first ARA release that installs core/ as the CMake package ara-core
# (swarm-routing/ARA#167), writing the version and the SHA512 of that release's asset.
# core/ alone, swarm-core from its port: find_package(ara-core CONFIG REQUIRED),
# target ara::core.
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/ARA/releases/download/v${VERSION}/ara-${VERSION}.tar.gz"
    FILENAME "ara-${VERSION}.tar.gz"
    SHA512 c2e713bc58432dceaf12d0593026027039be764999d5d787600c5683c77d0a9d822a3628dd9710de264c750c943499b2686cbef86cc218dfa35928cada94767c
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/core"
    OPTIONS
        -DARA_CORE_TESTS=OFF
        -DARA_CORE_SWARM_CORE_FROM_PACKAGE=ON
        -DARA_CORE_INSTALL=ON
        -DARA_CORE_VERSION=${VERSION}
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME ara-core CONFIG_PATH lib/cmake/ara-core)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/doc")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/core/LICENSE")
