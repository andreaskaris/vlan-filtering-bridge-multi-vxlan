#!/bin/sh
# host1 is a plain Linux host (agnhost) serving on :8889 via its entrypoint.
set -eux

LAST_OCTET=101

# agnhost listens in the default VRF; allow it to accept connections arriving
# on VRF-enslaved interfaces (otherwise TCP/UDP to VRF IPs is refused).
sysctl -w net.ipv4.tcp_l3mdev_accept=1
sysctl -w net.ipv4.udp_l3mdev_accept=1

ip link set tope1 up

bridgeid=1
vrf=1
ip link add vrf${vrf} type vrf table ${vrf}
ip link set dev vrf${vrf} up
for id in 10 12; do 
  ip link add link tope${bridgeid} name tope${bridgeid}.${id} type vlan id ${id}
  ip link set tope${bridgeid}.${id} up
  ip address add 10.0.${id}.${LAST_OCTET}/24 dev tope${bridgeid}.${id}
  ip link set dev tope${bridgeid}.${id} master vrf${vrf}
done
ip route add default via 10.0.12.1 vrf vrf${vrf}

bridgeid=2
vrf=2
ip link add vrf${vrf} type vrf table ${vrf}
ip link set dev vrf${vrf} up
for id in 20 22; do 
  ip link add link tope${bridgeid} name tope${bridgeid}.${id} type vlan id ${id}
  ip link set tope${bridgeid}.${id} up
  ip address add 10.0.${id}.${LAST_OCTET}/24 dev tope${bridgeid}.${id}
  ip link set dev tope${bridgeid}.${id} master vrf${vrf}
done
ip route add default via 10.0.22.1 vrf vrf${vrf}

# tope3: untagged L2 service (no VLAN) in vrf3, mapped to L2VNI 30 on the PEs.
vrf=3
ip link add vrf${vrf} type vrf table ${vrf}
ip link set dev vrf${vrf} up
ip link set tope3 up
ip link set dev tope3 master vrf${vrf}
ip address add 10.0.30.${LAST_OCTET}/24 dev tope3

# tope4: untagged L2 service (no VLAN) in vrf4, mapped to L2VNI 40 on the PEs.
vrf=4
ip link add vrf${vrf} type vrf table ${vrf}
ip link set dev vrf${vrf} up
ip link set tope4 up
ip link set dev tope4 master vrf${vrf}
ip address add 10.0.40.${LAST_OCTET}/24 dev tope4
