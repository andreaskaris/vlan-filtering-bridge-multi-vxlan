#!/bin/sh
# host0 is a plain Linux host (agnhost) serving on :8889 via its entrypoint.
set -eux

LAST_OCTET=100

ip link set tope0 up

bridgeid=0
vrf=1
ip link add vrf${vrf} type vrf table ${vrf}
ip link set dev vrf${vrf} up
for id in 10 11; do 
  ip link add link tope${bridgeid} name tope${bridgeid}.${id} type vlan id ${id}
  ip link set tope${bridgeid}.${id} up
  ip address add 10.0.${id}.${LAST_OCTET}/24 dev tope${bridgeid}.${id}
  ip link set dev tope${bridgeid}.${id} master vrf${vrf}
done
ip route add default via 10.0.11.1 vrf vrf${vrf}

bridgeid=1
vrf=2
ip link add vrf${vrf} type vrf table ${vrf}
ip link set dev vrf${vrf} up
for id in 20 21; do 
  ip link add link tope${bridgeid} name tope${bridgeid}.${id} type vlan id ${id}
  ip link set tope${bridgeid}.${id} up
  ip address add 10.0.${id}.${LAST_OCTET}/24 dev tope${bridgeid}.${id}
  ip link set dev tope${bridgeid}.${id} master vrf${vrf}
done
ip route add default via 10.0.21.1 vrf vrf${vrf}
