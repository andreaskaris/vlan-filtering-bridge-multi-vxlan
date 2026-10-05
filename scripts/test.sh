#!/bin/sh
set -eu
set -o pipefail

LAB="${LAB:-pe-lab}"
DOCKER="${DOCKER:-docker}"
COUNT="${COUNT:-1}"

vrf=1
for host in host0 host1; do
	ctr="clab-${LAB}-${host}"
	if [ "$host" = "host0" ]; then
		peer=101
    subnets="10 12"
	else
		peer=100
    subnets="10 11"
	fi
	for subnet in $subnets; do
		target="10.0.${subnet}.${peer}"
		echo "==> ${host}: ip vrf exec vrf${vrf} ping ${target}"
		$DOCKER exec "$ctr" ip vrf exec "vrf${vrf}" ping -c "$COUNT" -W 1 "$target" >/dev/null 2>&1 && echo "PASS" || echo "FAIL"
    if ! [ $? ]; then
      exit 1
    fi
	done
done

vrf=2
for host in host0 host1; do
	ctr="clab-${LAB}-${host}"
	if [ "$host" = "host0" ]; then
		peer=101
    subnets="20 22"
	else
		peer=100
    subnets="20 21"
	fi
	for subnet in $subnets; do
		target="10.0.${subnet}.${peer}"
		echo "==> ${host}: ip vrf exec vrf${vrf} ping ${target}"
		$DOCKER exec "$ctr" ip vrf exec "vrf${vrf}" ping -c "$COUNT" -W 1 "$target" >/dev/null 2>&1 && echo "PASS" || echo "FAIL"
    if ! [ $? ]; then
      exit 1
    fi
	done
done
