#!/bin/sh
# pe0 FRR node setup.
set -eux

LOOPBACK_IP=192.0.2.0

# Loopback IP.
ip address add ${LOOPBACK_IP}/32 dev lo

# Enable IPv6 on the link towards pe1 (tope).
sysctl -w net.ipv6.conf.tope.disable_ipv6=0

ip link add vrf1 type vrf table 1100
ip link set vrf1 up
ip link add vrf2 type vrf table 1200
ip link set vrf2 up

#########################
# L3VNIs below
########################
ip link add brl3 type bridge vlan_filtering 1 vlan_default_pvid 0
ip link add vxlanl3 type vxlan dstport 4789 local ${LOOPBACK_IP} nolearning external vnifilter
ip link set brl3 addrgenmode none
ip link set vxlanl3 addrgenmode none master brl3
ip link set brl3 address 10:22:33:44:55:$(printf %x 100)
ip link set vxlanl3 address 10:22:33:44:55:$(printf %x 100)
ip link set brl3 up
ip link set vxlanl3 up
bridge link set dev vxlanl3 vlan_tunnel on neigh_suppress on learning off

bridge vlan add dev brl3 vid 1100 self
bridge vlan add dev vxlanl3 vid 1100
bridge vni add dev vxlanl3 vni 1100 # add vni if using vnifilter
bridge vlan add dev vxlanl3 vid 1100 tunnel_info id 1100 # map vlan to vni
ip link add vlan1100 link brl3 type vlan id 1100 # create vlan on top of bridge
ip link set vlan1100 address 10:22:33:44:11:$(printf '%02x' ${LOOPBACK_IP##*.}) addrgenmode none # per-VTEP-unique RMAC (FRR drops routes whose RMAC == own RMAC)
ip link set vlan1100 master vrf1 # bind the device to the correct VRF, no address for L3VNI
ip link set vlan1100 up

bridge vlan add dev brl3 vid 1200 self
bridge vlan add dev vxlanl3 vid 1200
bridge vni add dev vxlanl3 vni 1200 # add vni if using vnifilter
bridge vlan add dev vxlanl3 vid 1200 tunnel_info id 1200 # map vlan to vni
ip link add vlan1200 link brl3 type vlan id 1200 # create vlan on top of bridge
ip link set vlan1200 address 10:22:33:44:12:$(printf '%02x' ${LOOPBACK_IP##*.}) addrgenmode none # per-VTEP-unique RMAC (FRR drops routes whose RMAC == own RMAC)
ip link set vlan1200 master vrf2 # bind the device to the correct VRF, no address for L3VNI
ip link set vlan1200 up

#########################
# L2VNIs below
########################
for bridgeid in 0 1; do
  ip link add br${bridgeid} type bridge vlan_filtering 1 vlan_default_pvid 0
  ip link set tohost${bridgeid} master br${bridgeid}
  ip link add vxlan${bridgeid} type vxlan dstport 4789 local ${LOOPBACK_IP} nolearning external vnifilter
  ip link set br${bridgeid} addrgenmode none
  ip link set vxlan${bridgeid} addrgenmode none master br${bridgeid}
  ip link set br${bridgeid} address 10:22:33:44:55:$(printf %x ${bridgeid})
  ip link set vxlan${bridgeid} address 10:22:33:44:55:$(printf %x ${bridgeid})
  ip link set br${bridgeid} up
  ip link set vxlan${bridgeid} up
  bridge link set dev vxlan${bridgeid} vlan_tunnel on neigh_suppress on learning off
done

bridgeid=0
vrf=1
for vid in 10 11; do
  bridge vlan add dev br${bridgeid} vid ${vid} self
  bridge vlan add dev vxlan${bridgeid} vid ${vid}
  bridge vni add dev vxlan${bridgeid} vni ${vid}
  bridge vlan add dev vxlan${bridgeid} vid ${vid} tunnel_info id ${vid}
  ip link add vlan${vid} link br${bridgeid} type vlan id ${vid}
  ip link set vlan${vid} up
  bridge vlan add dev tohost${bridgeid} vid ${vid}

  ip link set vlan${vid} master vrf${vrf} # bind L2VNI to L3VNI (vrf1)

  # anycast gateway setup
  # non-macvlan variant (anycast MAC + gateway IP directly on the SVI):
  ip link set vlan${vid} addr aa:bb:cc:00:00:$(printf %x ${vid}) #  anycast mac on vlan interface (or use anycast MAC on macvlan, see below)
  bridge fdb add aa:bb:cc:00:00:$(printf %x ${vid}) dev br${bridgeid} vlan ${vid} self local
  ip addr add 10.0.${vid}.1/24 dev vlan${vid} # shared gateway IP per L2VNI, on all VTEPs
  ip addr add 2001:db8:0:${vid}::1/64 dev vlan${vid}

  # anycast gateway setup - macvlan variant per
  # https://docs.frrouting.org/en/latest/evpn.html#anycast-gateways-with-single-vxlan-device
  # Create a macvlan on the L2VNI SVI to serve as the anycast gateway.
  # ip link add vlan${vid}agw link vlan${vid} type macvlan mode private
  # ip link set vlan${vid}agw addr aa:bb:cc:00:00:$(printf %x ${vid}) # same anycast MAC on all VTEPs
  # ip link set vlan${vid}agw master vrf${vrf} # gateway address lives in the tenant VRF
  # ip addr add 10.0.${vid}.1/24 dev vlan${vid}agw
  # ip addr add 2001:db8:0:${vid}::1/64 dev vlan${vid}agw
  # # Critical: local FDB entry so the anycast MAC is never sent over the overlay.
  # bridge fdb add aa:bb:cc:00:00:$(printf %x ${vid}) dev br${bridgeid} self local
  # ip link set vlan${vid}agw up
done

bridgeid=1
vrf=2
for vid in 20 21; do
  bridge vlan add dev br${bridgeid} vid ${vid} self
  bridge vlan add dev vxlan${bridgeid} vid ${vid}
  bridge vni add dev vxlan${bridgeid} vni ${vid}
  bridge vlan add dev vxlan${bridgeid} vid ${vid} tunnel_info id ${vid}
  ip link add vlan${vid} link br${bridgeid} type vlan id ${vid}
  ip link set vlan${vid} up
  bridge vlan add dev tohost${bridgeid} vid ${vid}

  ip link set vlan${vid} master vrf${vrf} # bind L2VNI to L3VNI (vrf2)

  # anycast gateway setup
  # non-macvlan variant (anycast MAC + gateway IP directly on the SVI):
  ip link set vlan${vid} addr aa:bb:cc:00:00:$(printf %x ${vid}) #  anycast mac on vlan interface (or use anycast MAC on macvlan, see below)
  bridge fdb add aa:bb:cc:00:00:$(printf %x ${vid}) dev br${bridgeid} vlan ${vid} self local
  ip addr add 10.0.${vid}.1/24 dev vlan${vid} # shared gateway IP per L2VNI, on all VTEPs
  ip addr add 2001:db8:0:${vid}::1/64 dev vlan${vid}

  # anycast gateway setup - macvlan variant per
  # https://docs.frrouting.org/en/latest/evpn.html#anycast-gateways-with-single-vxlan-device
  # Create a macvlan on the L2VNI SVI to serve as the anycast gateway.
  # ip link add vlan${vid}agw link vlan${vid} type macvlan mode private
  # ip link set vlan${vid}agw addr aa:bb:cc:00:00:$(printf %x ${vid}) # same anycast MAC on all VTEPs
  # ip link set vlan${vid}agw master vrf${vrf} # gateway address lives in the tenant VRF
  # ip addr add 10.0.${vid}.1/24 dev vlan${vid}agw
  # ip addr add 2001:db8:0:${vid}::1/64 dev vlan${vid}agw
  # # Critical: local FDB entry so the anycast MAC is never sent over the overlay.
  # bridge fdb add aa:bb:cc:00:00:$(printf %x ${vid}) dev br${bridgeid} self local
  # ip link set vlan${vid}agw up
done



