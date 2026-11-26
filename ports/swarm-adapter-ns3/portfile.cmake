# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# swarm-adapter-ns3's ns-3 module swarm-core (libns3.<ver>-swarm-core: the
# ns-3 adapter of swarm-core's ports, SwarmRoutingBase and the link monitors),
# from its release asset swarm-core-<ver>.tar.gz (top directory swarm-core/),
# built against the ns3 port's ns-3 through the ns3 port's contrib build
# (share/ns3/contrib) and on the swarm-core port (SWARM_CORE_FROM_PACKAGE, from
# the first release that has it, swarm-routing/swarm-adapter-ns3's next):
# find_package(swarm-adapter-ns3 CONFIG REQUIRED), target ns3::swarm-core.
# Saved as swarm-adapter-ns3-<ver>.tar.gz: the swarm-core port's asset has the
# same file name. The SHA512 is written by tools/port_bump.py from the
# downloaded asset, never by hand.
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/swarm-adapter-ns3/releases/download/v${VERSION}/swarm-core-${VERSION}.tar.gz"
    FILENAME "swarm-adapter-ns3-${VERSION}.tar.gz"
    SHA512 ac32604db1670082eadf3c1a060b5c3aaa66840c3505f6c010ececaade872790fa4b5f03eb9e20afd2baa35114f929c518edea661fefe1830fa62e92ce7a8999
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

vcpkg_cmake_configure(
    SOURCE_PATH "${CURRENT_INSTALLED_DIR}/share/ns3/contrib"
    OPTIONS
        "-DNS3_CONTRIB_PACKAGE=${PORT}"
        "-DNS3_CONTRIB_MODULES=${SOURCE_PATH}"
        -DNS3_CONTRIB_DEPENDENCIES=swarm-core
        -DSWARM_CORE_FROM_PACKAGE=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME ${PORT} CONFIG_PATH share/${PORT})
vcpkg_copy_tools(TOOL_NAMES swarm-core-seed swarm-core-queue-bench AUTO_CLEAN)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
