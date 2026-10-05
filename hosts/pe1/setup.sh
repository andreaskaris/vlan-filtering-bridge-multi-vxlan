#!/bin/sh
# pe1 FRR node setup.
set -eux

# Loopback IP.
ip address add 192.0.2.1/32 dev lo

# Enable IPv6 on the link towards pe0 (tope) and assign an address.
sysctl -w net.ipv6.conf.tope.disable_ipv6=0
