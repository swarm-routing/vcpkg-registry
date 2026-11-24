// Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
// SPDX-License-Identifier: MIT OR GPL-2.0-only
//
// The scratch consumer of the ns3 port (#76): two nodes on a point-to-point
// link, a UDP echo client and server, routed by the installed internet
// module. It passes when the echo comes back, so ns-3's libraries load, their
// TypeIds are registered (the shared-library build) and a packet crosses the
// stack. With the sim-tools-ns3 port, it also links routing-bench.
#include "ns3/applications-module.h"
#include "ns3/core-module.h"
#include "ns3/internet-module.h"
#include "ns3/network-module.h"
#include "ns3/point-to-point-module.h"
#ifdef CONSUMER_ROUTING_BENCH
#include "ns3/routing-bench-module.h"
#endif

#include <cstdio>

using namespace ns3;

int main() {
    NodeContainer nodes;
    nodes.Create(2);
    PointToPointHelper p2p;
    NetDeviceContainer devices = p2p.Install(nodes);
    InternetStackHelper stack;
    stack.Install(nodes);
    Ipv4AddressHelper address;
    address.SetBase("10.1.1.0", "255.255.255.0");
    Ipv4InterfaceContainer ifaces = address.Assign(devices);

    UdpEchoServerHelper server(9);
    ApplicationContainer serverApps = server.Install(nodes.Get(1));
    serverApps.Start(Seconds(0.5));
    UdpEchoClientHelper client(ifaces.GetAddress(1), 9);
    client.SetAttribute("MaxPackets", UintegerValue(1));
    ApplicationContainer clientApps = client.Install(nodes.Get(0));
    clientApps.Start(Seconds(1.0));

    uint32_t echoed = 0;
    Ptr<UdpEchoClient> app = DynamicCast<UdpEchoClient>(clientApps.Get(0));
    app->TraceConnectWithoutContext(
        "Rx", Callback<void, Ptr<const Packet>>([&echoed](Ptr<const Packet>) { ++echoed; }));

    Simulator::Stop(Seconds(3.0));
    Simulator::Run();
    Simulator::Destroy();
    const bool ok = echoed == 1;
    std::puts(ok ? "consumer-ns3: ok" : "consumer-ns3: FAILED");
    return ok ? 0 : 1;
}
