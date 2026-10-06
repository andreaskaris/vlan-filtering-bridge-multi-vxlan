# pe-lab

A small [Containerlab](https://containerlab.dev/) topology with two Linux hosts
(`agnhost`) connected through two FRR PE routers running EVPN/VXLAN.

- **host0**, **host1** — plain Linux hosts (`agnhost`), serving on `:8889`.
- **pe0**, **pe1** — FRR 10.7.1 routers (VTEPs), connected by an eBGP-unnumbered
  core link that carries the EVPN overlay.

## Topology

```
   +--------------------------------------+                                         +--------------------------------------+
   |                host0                 |                                         |                host1                 |
   |            (agnhost host)            |                                         |            (agnhost host)            |
   |                                      |                                         |                                      |
   |   tope1   tope2   tope3   tope4      |                                         |   tope1   tope2   tope3   tope4      |
   +-----+-------+-------+-------+--------+                                         +-----+-------+-------+-------+--------+
         |       |       |       |                                                        |       |       |       |
         |       |       |       |                                                        |       |       |       |
      tohost1 tohost2 tohost3 tohost4                                                  tohost1 tohost2 tohost3 tohost4
   +-----+-------+-------+-------+--------+           tope <-------> tope           +-----+-------+-------+-------+--------+
   |                 pe0                  |=========================================|                 pe1                  |
   |  FRR / VTEP                          |        eBGP unnumbered (IPv6 LL)        |  FRR / VTEP                          |
   |  lo 192.0.2.0                        |      AF: ipv4 / ipv6 / l2vpn evpn       |  lo 192.0.2.1                        |
   |  AS 65000                            |                                         |  AS 65001                            |
   +--------------------------------------+                                         +--------------------------------------+
```

## Inside pe0

Datapath wiring built by `hosts/pe0/setup.sh`. Each tenant VRF holds its L2VNI
SVIs plus one L3VNI SVI. L2 traffic rides the per-tenant bridges (`br1`/`br2`)
and their VXLAN devices; inter-subnet/routed traffic uses the L3VNI bridge
(`brl3` / `vxlanl3`). All VXLAN devices share `local 192.0.2.0`, dstport 4789,
and send the overlay out over the `tope` core link to pe1.

pe1's setup is nearly identical, with the exception that it uses L2VNIs 10, 12 and 20, 22 respectively.

```
                         host0:tope1                                                  host0:tope2                                                 host0:tope3                       
                             |                                                            |                                                           |                            
                             |                                                            |                                                           |                            
  +--------------------------|---------------------------+     +--------------------------|---------------------------+    +--------------------------|---------------------------+
  | br1                      |                           |     | br2                      |                           |    | br3                      |                           |
  |               +---------------------+                |     |               +---------------------+                |    |          +----------------------------------+        |
  |               |     tohost1         |                |     |               |     tohost2         |                |    |          |     tohost3                      |        |
  |               |  (trunk vlan 10,11) |                |     |               |  (trunk vlan 20,21) |                |    |          |  (untagged on link, vid 1 on br) |        |
  |               +---------------------+                |     |               +---------------------+                |    |          +----------------------------------+        |
  |  +-------------+ +---------------+ +---------------+ |     |  +-------------+ +---------------+ +---------------+ |    |  +-------------+ +---------------+                   |
  |  | vxlan1      | | vlan1.10      | | vlan1.11      | |     |  | vxlan2      | | vlan2.20      | | vlan2.21      | |    |  | vxlan3      | | vlan3.1       |                   |
  |  | L2VNI 10,11 | | IP  10.0.10.1 | | IP 10.0.11.1  | |     |  | L2VNI 20,21 | | IP  10.0.20.1 | | IP  10.0.21.1 | |    |  | L2VNI 30    | | IP  10.0.30.1 |                   | 
  |  |             | | L2VNI 10      | | L2VNI 11      | |     |  |             | | L2VNI 20      | | L2VNI 21      | |    |  |             | | L2VNI 30      |                   | 
  |  +-------------+ +---------------+ +---------------+ |     |  +-------------+ +---------------+ +---------------+ |    |  +-------------+ +---------------+                   |
  +---------------------|-----------------|--------------+     +---------------------|-----------------|--------------+    +---------------------|--------------------------------+
                        |                 |                                          |                 |                                         |
                   +----+-----+           |                                     +----------+           |                                    +----------+
                   |   vrf1   |-----------/                                     |   vrf2   |-----------/                                    |   vrf3   |
                   | tbl 1100 |                                                 | tbl 1200 |                                                | tbl 1300 |
                   +----+-----+                                                 +----+-----+                                                +----+-----+
                        |                                                            |
                        |                                                            |
                +-----------------------------------------------------------------------------+
                |       |                          brl3                              |        |
                | +-----+------+                                               +-----+------+ |
                | |  vlan1100  |       +------------------------------+        |  vlan1200  | |
                | | L3VNI 1100 |       |  vxlanl3   L3VNI 1100, 1200  |        | L3VNI 1200 | |
                | +-----+------+       +------------------------------+        +-----+------+ |
                +-----------------------------------------------------------------------------+
```

Legend:
- `br1`/`br2` — tenant L2 bridges; `tohost1`/`tohost2` are 802.1Q trunks to host0.
- `vxlan1`/`vxlan2` — L2VNI VTEPs (VNI = VLAN id: 10, 11, 20, 21).
- `vlanB.NN` SVIs — anycast gateways (`10.0.NN.1`, `2001:db8:0:NN::1`), enslaved to
  their VRF (`vlan1.10/1.11` → `vrf1`, `vlan2.20/2.21` → `vrf2`).
- `vlan1100`/`vlan1200` — L3VNI SVIs bound to `vrf1`/`vrf2`, on bridge `brl3`.
- `vxlanl3` — L3VNI VTEP (VNI 1100/1200) for routed (symmetric) traffic.

### Links (from `pe-lab.clab.yml`)

| A end          | B end          |
|----------------|----------------|
| host0:tope1    | pe0:tohost1    |
| host0:tope2    | pe0:tohost2    |
| host0:tope3    | pe0:tohost3    |
| host0:tope4    | pe0:tohost4    |
| pe0:tope       | pe1:tope       |
| pe1:tohost1    | host1:tope1    |
| pe1:tohost2    | host1:tope2    |
| pe1:tohost3    | host1:tope3    |
| pe1:tohost4    | host1:tope4    |

## Overlay details

Each host attaches to a PE over two physical links (`tope1`, `tope2`), each
carrying VLAN sub-interfaces that map to L2VNIs on the PE. The PEs stitch these
together across the core link using EVPN (VXLAN, UDP 4789).

| VRF   | L3VNI | PE SVI/L2VNIs (VLAN = VNI)          | Host subnets           |
|-------|-------|------------------------------------|------------------------|
| vrf1  | 1100  | pe0: 10, 11 — pe1: 10, 12          | `10.0.<vid>.0/24`, `2001:db8:0:<vid>::/64` |
| vrf2  | 1200  | pe0: 20, 21 — pe1: 20, 22          | `10.0.<vid>.0/24`, `2001:db8:0:<vid>::/64` |
| vrf3  | —     | VNI 30 (untagged, local vid 1)     | `10.0.30.0/24` |
| vrf4  | —     | VNI 40 (untagged, local vid 1)     | `10.0.40.0/24` |

- `tope1` → bridge `br1` → `vrf1` (VLANs 10/11 on pe0, 10/12 on pe1)
- `tope2` → bridge `br2` → `vrf2` (VLANs 20/21 on pe0, 20/22 on pe1)
- `tope3` → bridge `br3` → `vrf3` (untagged, L2VNI 30 on both PEs)
- `tope4` → bridge `br4` → `vrf4` (untagged, L2VNI 40 on both PEs)

`tope3`/`tohost3` and `tope4`/`tohost4` carry plain untagged traffic (no 802.1Q
tag). On the PEs each lands on its own bridge (`br3`/`br4`) as an access port:
frames are untagged on the `tohostN` link, but inside the bridge they are tagged
with the local `vid 1`, which is mapped to L2VNI 30/40 (`vid 0` is not a valid
bridge VLAN, so `vid 1` is used as the internal access VLAN). The anycast-gateway
SVI for each subnet lives in its VRF (`vrf3`/`vrf4`). On the hosts, `tope3`/`tope4`
are enslaved directly to `vrf3`/`vrf4`. These are L2-only stretches for now — no
L3VNI is wired for `vrf3`/`vrf4` (nothing is added on top of `brl3` yet), so there
is no symmetric inter-subnet routing for these tenants.

You can confirm the VLAN-to-VNI mapping on a PE with `bridge vlan tunnelshow`:

```
pe0:/# bridge vlan tunnelshow
port              vlan-id    tunnel-id
vxlanl3           1100       1100
                  1200       1200
vxlan1            10-11      10-11
vxlan2            20-21      20-21
vxlan3            1          30
vxlan4            1          40
```

Anycast gateways (`10.0.<vid>.1`, `2001:db8:0:<vid>::1`, MAC
`aa:bb:cc:00:00:<vid>`) live on every VTEP, so hosts use the same default
gateway regardless of which PE they are attached to.

Host addresses end in `.100` (host0) and `.101` (host1).

## Usage

Bring up the lab:

```sh
make deploy
```

Verify host-to-host connectivity across the overlay:

```sh
make test
```

`make test` runs `scripts/test.sh`, which pings each host's peer (`.100` ↔
`.101`) inside `vrf1`, `vrf2`, `vrf3`, and `vrf4` and prints `PASS`/`FAIL` per
subnet. Set `COUNT` to send more probes per check (e.g. `make test COUNT=3`).

The hosts run `agnhost netexec` on port `8889`, so you can also probe the
overlay with HTTP. Run `curl` inside the sending host's VRF:

```sh
# For connections across the L2VNI
docker exec -it clab-pe-lab-host0 ip vrf exec vrf1 curl http://10.0.10.101:8889/hostname
docker exec -it clab-pe-lab-host0 ip vrf exec vrf1 curl http://10.0.10.101:8889/clientip
docker exec -it clab-pe-lab-host0 ip vrf exec vrf1 curl "http://10.0.10.101:8889/echo?msg=hello"

# For connections across the L3VNI
docker exec -it clab-pe-lab-host0 ip vrf exec vrf1 curl http://10.0.12.101:8889/hostname
docker exec -it clab-pe-lab-host0 ip vrf exec vrf1 curl http://10.0.12.101:8889/clientip
docker exec -it clab-pe-lab-host0 ip vrf exec vrf1 curl "http://10.0.12.101:8889/echo?msg=hello"
```

`/hostname` confirms which peer answered, and `/clientip` shows the source
address seen across the overlay.

Tear the lab down when you're done:

```sh
make destroy
```

Use `make redeploy` to rebuild (`destroy` then `deploy`), or
`make cleanup` to destroy and also remove the generated lab directory.
