# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# Stock ns-3 from its release tarball (https://www.nsnam.org/releases/), the
# release swarm-routing/sim-containers' `latest` images build, with the
# modules those images enable (sim-containers docker/Dockerfile NS3_MODULES)
# and the ones they pull in. Installed as ns-3's own CMake package:
# find_package(ns3 CONFIG REQUIRED), targets ns3::<module> (ns3::core, ...)
# (#76, epic swarm-routing/.github#881).
#
# Shared libraries only: ns-3 registers its TypeIds and test suites from
# static initialisers, which a static link drops unless every archive is
# linked whole. The SHA512 is written by tools/port_bump.py from the
# downloaded tarball, checked first against the SHA-1 the release's download
# page lists (CHECKSUM_PAGE below), never by hand.
#
# Stock on purpose: the images stay stock and the org works around ns-3 bugs
# in its own code (swarm-routing/sim-tools docs/ns3-bugs.md, maintainer
# decision 2026-11-23), so this port carries no patch. On ns-3.49:
#   NS3-001  stock AODV livelocks in a zero-time ICMP "net unreachable" storm
#            (nsnam/ns-3-dev#1408, fix nsnam/ns-3-dev!3101 open): routing-bench
#            (the routing-bench port) installs its aodv arm behind
#            IcmpErrorGuardHelper; a program running stock AODV here is exposed.
#   NS3-002  AODV and DSDV order per-interface sockets by heap address
#            (nsnam/ns-3-dev#1409): routing-bench's --isolateArms (default).
#   NS3-003  DSDV sends on a route with a null output device
#            (nsnam/ns-3-dev#1364): avoid dsdv on multi-interface topologies.
# A later ns-3 release that fixes one drops its line here, in the same bump.
#
# Read by tools/port_bump.py (`bump --port ns3 --tag ns-3.49`): the tag's
# form, and the release page that lists the tarball's SHA-1.
# RELEASE_TAG ns-${VERSION}
# CHECKSUM_PAGE https://www.nsnam.org/releases/ns-${VERSION_DASHED}/download/
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://www.nsnam.org/releases/ns-${VERSION}.tar.bz2"
    FILENAME "ns-${VERSION}.tar.bz2"
    SHA512 d18a44d0acc570ff1d3ef99632ff5493d2b204eb9e0c3ba20059cdea772ac36f0808c00a95e04327541f374902297de14acd5bb7cddabaf42348f3348485c7c6
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# The modules of the images (sim-containers docker/Dockerfile NS3_MODULES);
# ns-3 adds their dependencies (propagation, spectrum, antenna, bridge,
# traffic-control, ...). No optional third-party library is searched for, so
# the build is the same on every machine: no GSL, SQLite, Eigen, GTK, MPI,
# emulation or tap devices, Python bindings, examples or tests.
set(NS3_MODULES "core;network;internet;wifi;mesh;mobility;energy;flow-monitor;applications;point-to-point;csma;aodv;olsr;dsdv;dsr;stats")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        "-DNS3_ENABLED_MODULES=${NS3_MODULES}"
        -DNS3_EXAMPLES=OFF
        -DNS3_TESTS=OFF
        -DNS3_PYTHON_BINDINGS=OFF
        -DNS3_WARNINGS_AS_ERRORS=OFF
        -DNS3_CCACHE=OFF
        -DNS3_FAST_LINKERS=OFF
        -DNS3_PRECOMPILE_HEADERS=OFF
        -DNS3_GSL=OFF
        -DNS3_SQLITE=OFF
        -DNS3_EIGEN=OFF
        -DNS3_GTK3=OFF
        -DNS3_MPI=OFF
        -DNS3_EMU=OFF
        -DNS3_TAP=OFF
        -DNS3_VISUALIZER=OFF
        -DNS3_NETANIM=OFF
        -DNS3_CPM=OFF
        -DNS3_VCPKG=OFF
        -DNS3_FETCH_OPTIONAL_COMPONENTS=OFF
        -DNS3_ENABLE_BUILD_VERSION=OFF
        # the release build keeps NS_ASSERT and NS_LOG, as ns-3's own
        # `default` profile: a library for simulations, not a benchmark binary
        -DNS3_ASSERT=ON
        -DNS3_LOG=ON
    # ns-3 writes its artifacts to <source>/build unless told otherwise; the
    # debug and release configures run side by side, so each gets its own
    OPTIONS_DEBUG
        "-DNS3_OUTPUT_DIRECTORY=${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/ns3-out"
    OPTIONS_RELEASE
        "-DNS3_OUTPUT_DIRECTORY=${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/ns3-out"
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME ns3 CONFIG_PATH lib/cmake/ns3)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share")
# The project the module ports (sim-tools-ns3, swarm-adapter-ns3) build ns-3
# contrib modules with, against this ns-3 (contrib/CMakeLists.txt).
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/contrib/CMakeLists.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/contrib")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
