# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# A template (templates/, not ports/): tools/port_bump.py moves it into ports/
# on the first AntHocNet release that installs core/ as the CMake package anthocnet-core
# (swarm-routing/AntHocNet#1037), writing the version and the SHA512 of that release's asset.
# core/ alone, swarm-core from its port: find_package(anthocnet-core CONFIG REQUIRED),
# target anthocnet::core.
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/AntHocNet/releases/download/v${VERSION}/anthocnet-${VERSION}.zip"
    FILENAME "anthocnet-${VERSION}.zip"
    SHA512 4846e60f3fa4cfa3891f39141e3c5a18c5be886d553c844a47d783f6e4c1d602b58c435b70c03308ac339ac2bd8a1287e3c1710296402cc4497e0f7a0ea1c739
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/core"
    OPTIONS
        -DANTHOCNET_CORE_TESTS=OFF
        -DANTHOCNET_CORE_SWARM_CORE_FROM_PACKAGE=ON
        -DANTHOCNET_CORE_INSTALL=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME anthocnet-core CONFIG_PATH lib/cmake/anthocnet-core)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/doc")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/core/LICENSE")
