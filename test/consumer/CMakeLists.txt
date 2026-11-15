# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# A project outside the org consuming the swarm-core port: vcpkg (manifest
# mode, vcpkg.json + vcpkg-configuration.json beside this file) installs it
# during configure, find_package finds the installed package.
cmake_minimum_required(VERSION 3.20)
project(swarm_core_port_consumer LANGUAGES CXX)

find_package(swarm-core CONFIG REQUIRED)
message(STATUS "swarm-core ${swarm-core_VERSION} from ${swarm-core_DIR}")

add_executable(consumer consumer.cc)
target_link_libraries(consumer PRIVATE swarm::core)
