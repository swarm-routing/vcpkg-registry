# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# swarm-core's core/ from its published release tarball (swarm-core-<ver>.tar.gz,
# top directory swarm-core/), installed as the CMake package swarm-core
# (swarm-routing/swarm-adapter-ns3#133): find_package(swarm-core CONFIG REQUIRED),
# target swarm::core. Released from swarm-routing/swarm-core from 2.0.0 on
# (swarm-routing/swarm-core#10, #50); 1.0.0 and earlier from
# swarm-routing/swarm-adapter-ns3 (then ns3-swarm-core). The SHA512 is written
# by tools/port_bump.py from the downloaded asset, never by hand.
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/swarm-core/releases/download/v${VERSION}/swarm-core-${VERSION}.tar.gz"
    FILENAME "swarm-core-${VERSION}.tar.gz"
    SHA512 bb93a607fdd4852e7716c92a5025b56a8e32084890839ce31a1d375c22e3e6bf0b5e2c2559bee0b30e72cb5f5360c4475b3de9019d1e5a6d706c434fa978c47e
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# core/ alone (the tarball carries no ns-3 module from 2.0.0 on; up to 1.0.0 it
# sat in ../ and was not part of the port); its tests and microbenchmarks stay
# off, the install rules on.
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
