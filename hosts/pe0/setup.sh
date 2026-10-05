#!/bin/sh
# pe0 FRR node setup.
set -eux

# Loopback IP.
ip address add 192.0.2.0/32 dev lo

# Enable IPv6 on the link towards pe1 (tope).
sysctl -w net.ipv6.conf.tope.disable_ipv6=0
