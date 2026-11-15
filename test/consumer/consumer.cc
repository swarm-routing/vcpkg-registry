// Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
// SPDX-License-Identifier: MIT OR GPL-2.0-only
//
// The scratch consumer of the swarm-core port: it calls a function compiled
// into the installed static library (so the link is real) and runs the
// header-only testbench, as a protocol's core test would.
#include "swarm-selection.h"
#include "testbench/swarm-testbench.h"

#include <array>
#include <cstdio>
#include <memory>

namespace {

/// Rebroadcasts the first message it hears: a flood over the testbench.
struct Flood final : swarm::core::testbench::INodeAdapter<int> {
    explicit Flood(swarm::core::testbench::NodePorts<int>& p) : ports(p) {}
    void start() override {
        if (ports.address() == 0) {
            heard = true;
            ports.broadcast(1);
        }
    }
    void receive(swarm::core::NodeAddress, const int& m) override {
        if (!heard) {
            heard = true;
            ports.broadcast(m);
        }
    }
    swarm::core::testbench::NodePorts<int>& ports;
    bool heard = false;
};

struct NoRng final : swarm::core::IRng {
    double uniform() override { return 0.0; }
    int uniformInt(int) override { return 0; }
};

}  // namespace

int main() {
    using namespace swarm::core;
    const std::array<WeightedHop, 2> hops{WeightedHop{1, 0.0}, WeightedHop{2, 1.0}};
    const std::array<WeightedHop, 1> none{WeightedHop{1, 0.0}};
    NoRng rng;
    namespace tb = swarm::core::testbench;
    tb::Network<int> net(tb::Topology::line(4));
    net.install([](tb::NodePorts<int>& p) { return std::make_unique<Flood>(p); });
    net.run(1.0);
    const bool ok = rouletteSelect(none, rng) == kInvalidAddress &&
                    rouletteSelect(hops, rng) == 2 && net.sentTotal() == 4;
    std::puts(ok ? "consumer: ok" : "consumer: FAILED");
    return ok ? 0 : 1;
}
