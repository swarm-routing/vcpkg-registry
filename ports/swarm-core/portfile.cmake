# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# swarm-core's core/ from its published release tarball (swarm-core-<ver>.tar.gz,
# top directory swarm-core/), installed as the CMake package swarm-core
# (swarm-routing/ns3-swarm-core#133): find_package(swarm-core CONFIG REQUIRED),
# target swarm::core. The SHA512 is written by tools/port_bump.py from the
# downloaded asset, never by hand.
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/ns3-swarm-core/releases/download/v${VERSION}/swarm-core-${VERSION}.tar.gz"
    FILENAME "swarm-core-${VERSION}.tar.gz"
    SHA512 5f58e3464fd4f1db25be60904fa0fcb623adb64d2712e0085389edeb9af59179e423e7e3559c8ad6c8d2a7f2e495620db785ae561a2c1422e3eb07227c805dd1
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# core/ alone (the ns-3 module in ../ is not part of the port); its tests and
# microbenchmarks stay off, the install rules on.
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/core"
    OPTIONS
        -DSWARM_CORE_TESTS=OFF
        -DSWARM_CORE_BENCH=OFF
        -DSWARM_CORE_INSTALL=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME swarm-core CONFIG_PATH lib/cmake/swarm-core)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/doc")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/core/LICENSE")
