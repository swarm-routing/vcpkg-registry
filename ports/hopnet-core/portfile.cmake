# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# A template (templates/, not ports/): tools/port_bump.py moves it into ports/
# on the first HOPNET release that installs core/ as the CMake package hopnet-core
# (swarm-routing/HOPNET#143), writing the version and the SHA512 of that release's asset.
# core/ alone, swarm-core from its port: find_package(hopnet-core CONFIG REQUIRED),
# target hopnet::core.
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/swarm-routing/HOPNET/releases/download/v${VERSION}/hopnet-${VERSION}.tar.gz"
    FILENAME "hopnet-${VERSION}.tar.gz"
    SHA512 8af79765b656abb84f9f044ead3f85aef44aa54a07b0416e92cb1c865fa4591ac4c219d7048c6a776565fa176b0c5b7703a79c925085a9eecec7478e8877d62f
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/core"
    OPTIONS
        -DHOPNET_CORE_TESTS=OFF
        -DHOPNET_CORE_SWARM_CORE_FROM_PACKAGE=ON
        -DHOPNET_CORE_INSTALL=ON
        -DHOPNET_CORE_VERSION=${VERSION}
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME hopnet-core CONFIG_PATH lib/cmake/hopnet-core)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/doc")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/core/LICENSE")
