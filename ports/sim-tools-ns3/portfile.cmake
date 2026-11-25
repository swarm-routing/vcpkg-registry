# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# sim-tools' ns-3 package: the modules of its ns3/ folder (routing-bench, the
# protocol-agnostic comparison harness with the stock arms), one port per
# simulator folder of swarm-routing/sim-tools. Built from the release asset
# routing-bench-<ver>.tar.gz (top directory routing-bench/) against the ns3
# port's ns-3, through the ns3 port's contrib build (share/ns3/contrib):
# find_package(sim-tools-ns3 CONFIG REQUIRED), target ns3::routing-bench,
# and the programs routing-compare and anthocnet-compare in tools/sim-tools-ns3/.
# The SHA512 is written by tools/port_bump.py from the downloaded asset,
# never by hand.
#
# ns-3 bugs it carries the org's workarounds for (swarm-routing/sim-tools
# docs/ns3-bugs.md): NS3-001, the aodv arm behind IcmpErrorGuardHelper;
# NS3-002, --isolateArms on by default.
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/sim-tools/releases/download/v${VERSION}/routing-bench-${VERSION}.tar.gz"
    FILENAME "routing-bench-${VERSION}.tar.gz"
    SHA512 930ef1e7d34dead06876e5286db08bf998debeb6c4be2fb065d76a122334926d8df0e4a1c099e25104a88816e5f33fb0b707d1853782d30f689a8252a1c95343
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

vcpkg_cmake_configure(
    SOURCE_PATH "${CURRENT_INSTALLED_DIR}/share/ns3/contrib"
    OPTIONS
        "-DNS3_CONTRIB_PACKAGE=${PORT}"
        "-DNS3_CONTRIB_MODULES=${SOURCE_PATH}"
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME ${PORT} CONFIG_PATH share/${PORT})
vcpkg_copy_tools(TOOL_NAMES routing-compare anthocnet-compare AUTO_CLEAN)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
