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

# The ns-3 ports (x64-linux only, #76): CONSUMER_PORTS is the list CI installs
# on this triplet; each ns-3 port in it must be found.
set(CONSUMER_PORTS "" CACHE STRING "the ports vcpkg installed for this triplet")
if("ns3" IN_LIST CONSUMER_PORTS)
  find_package(ns3 CONFIG REQUIRED)
  add_executable(consumer-ns3 consumer-ns3.cc)
  # ns-3.49's headers need C++23; its exported targets do not say so
  target_compile_features(consumer-ns3 PRIVATE cxx_std_23)
  target_link_libraries(consumer-ns3 PRIVATE
    ns3::core ns3::network ns3::internet ns3::point-to-point ns3::applications)
  if("sim-tools-ns3" IN_LIST CONSUMER_PORTS)
    find_package(sim-tools-ns3 CONFIG REQUIRED)
    target_link_libraries(consumer-ns3 PRIVATE ns3::routing-bench)
    target_compile_definitions(consumer-ns3 PRIVATE CONSUMER_ROUTING_BENCH)
  endif()
  if("swarm-adapter-ns3" IN_LIST CONSUMER_PORTS)
    find_package(swarm-adapter-ns3 CONFIG REQUIRED)
    target_link_libraries(consumer-ns3 PRIVATE ns3::swarm-core)
    target_compile_definitions(consumer-ns3 PRIVATE CONSUMER_SWARM_ADAPTER)
  endif()
endif()
