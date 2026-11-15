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
    SHA512 6d4dd2ad395ea8f76e515b76f87b3c7f8be091f4fbffd9b0c23de5770c1a6c40f2dcb92d5447aff64171b40709efaa3bcfc5d6559230e1b3fef21a87c029d839
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
