#!/bin/sh
set -u

LAB="${LAB:-pe-lab}"
DOCKER="${DOCKER:-docker}"
COUNT="${COUNT:-1}"

rc=0

# check <host> <vrf> <target-ip>
check() {
	host=$1
	vrf=$2
	target=$3
	ctr="clab-${LAB}-${host}"
	printf '==> %s: ip vrf exec vrf%s ping %s ... ' "$host" "$vrf" "$target"
	if $DOCKER exec "$ctr" ip vrf exec "vrf${vrf}" ping -c "$COUNT" -W 1 "$target" >/dev/null 2>&1; then
		echo "PASS"
	else
		echo "FAIL"
		rc=1
	fi
}

# vrf1 (L2VNI 10/11 on pe0, 10/12 on pe1; routed via L3VNI 1100)
check host0 1 10.0.10.101
check host0 1 10.0.12.101
check host1 1 10.0.10.100
check host1 1 10.0.11.100

# vrf2 (L2VNI 20/21 on pe0, 20/22 on pe1; routed via L3VNI 1200)
check host0 2 10.0.20.101
check host0 2 10.0.22.101
check host1 2 10.0.20.100
check host1 2 10.0.21.100

# vrf3 (untagged L2VNI 30; L2-only stretch, no L3VNI)
check host0 3 10.0.30.101
check host1 3 10.0.30.100

# vrf4 (untagged L2VNI 40; L2-only stretch, no L3VNI)
check host0 4 10.0.40.101
check host1 4 10.0.40.100

exit $rc
