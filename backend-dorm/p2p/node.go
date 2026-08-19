package p2p

import (
	"context"
	"fmt"
	"log"

	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/p2p/discovery/mdns"
)

const DiscoveryServiceTag = "dorm-p2p-sync"

type discoveryNotifee struct {
	h host.Host
}

// HandlePeerFound connects to peers discovered via mDNS
func (n *discoveryNotifee) HandlePeerFound(pi peer.AddrInfo) {
	if pi.ID == n.h.ID() {
		return // Ignore self
	}
	fmt.Printf("Discovered new peer: %s\n", pi.ID.String())
	err := n.h.Connect(context.Background(), pi)
	if err != nil {
		fmt.Printf("Error connecting to peer %s: %s\n", pi.ID.String(), err)
	} else {
		fmt.Printf("Connected to peer: %s\n", pi.ID.String())
	}
}

func StartP2PNode() (host.Host, error) {
	// Create a new libp2p Host that listens on a random TCP port
	h, err := libp2p.New(
		libp2p.ListenAddrStrings("/ip4/0.0.0.0/tcp/0"),
	)
	if err != nil {
		return nil, err
	}

	log.Printf("P2P Node started with ID: %s", h.ID())
	for _, addr := range h.Addrs() {
		log.Printf("Listening on: %s/p2p/%s", addr, h.ID())
	}

	// Setup local mDNS discovery
	mdnsService := mdns.NewMdnsService(h, DiscoveryServiceTag, &discoveryNotifee{h: h})
	if err := mdnsService.Start(); err != nil {
		return nil, err
	}

	return h, nil
}
