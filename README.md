# pe-lab

A small [Containerlab](https://containerlab.dev/) topology with two Linux hosts
(`agnhost`) connected through two FRR PE routers running EVPN/VXLAN.

- **host0**, **host1** — plain Linux hosts (`agnhost`), serving on `:8889`.
- **pe0**, **pe1** — FRR 10.7.1 routers (VTEPs), connected by an eBGP-unnumbered
  core link that carries the EVPN overlay.

## Topology

```
   +-----------------+                                         +-----------------+
   |      host0      |                                         |      host1      |
   |  (agnhost host) |                                         |  (agnhost host) |
   |                 |                                         |                 |
   |  tope0    tope1 |                                         |  tope0    tope1 |
   +----+--------+---+                                         +---+--------+----+
        |        |                                                  |        |
        |        |                                                  |        |
  tohost0     tohost1                                          tohost0     tohost1
   +----+--------+---+          tope <-------> tope            +---+---------+---+
   |      pe0        |=========================================|      pe1        |
   |  FRR / VTEP     |        eBGP unnumbered (IPv6 LL)        |  FRR / VTEP     |
   |  lo 192.0.2.0   |        AF: ipv4 / ipv6 / l2vpn evpn     |  lo 192.0.2.1   |
   |  AS 65000       |                                         |  AS 65001       |
   +-----------------+                                         +-----------------+
```

## Inside pe0

Datapath wiring built by `hosts/pe0/setup.sh`. Each tenant VRF holds its L2VNI
SVIs plus one L3VNI SVI. L2 traffic rides the per-tenant bridges (`br0`/`br1`)
and their VXLAN devices; inter-subnet/routed traffic uses the L3VNI bridge
(`brl3` / `vxlanl3`). All VXLAN devices share `local 192.0.2.0`, dstport 4789,
and send the overlay out over the `tope` core link to pe1.

pe1's setup is nearly identical, with the exception that it uses L2VNIs 10, 12 and 20, 22 respectively.

```
                         host0:tope0                                                  host0:tope1                       
                             |                                                            |                   
                             |                                                            |                   
  +--------------------------|---------------------------+     +--------------------------|---------------------------+  
  | br0                      |                           |     | br1                      |                           |  
  |               +---------------------+                |     |               +---------------------+                |  
  |               |     tohost0         |                |     |               |     tohost1         |                |  
  |               |  (trunk vlan 10,11) |                |     |               |  (trunk vlan 10,11) |                |  
  |               +---------------------+                |     |               +---------------------+                |  
  |  +-------------+ +---------------+ +---------------+ |     |  +-------------+ +---------------+ +---------------+ | 
  |  | vxlan0      | | vlan10        | | vlan11        | |     |  | vxlan1      | | vlan20        | | vlan21        | |
  |  | L2VNI 10,11 | | IP  10.0.10.1 | | IP 10.0.11.1  | |     |  | L2VNI 20,21 | | IP  10.0.20.1 | | IP  10.0.21.1 | |   
  |  |             | | L2VNI 10      | | L2VNI 11      | |     |  |             | | L2VNI 20      | | L2VNI 21      | |   
  |  +-------------+ +---------------+ +---------------+ |     |  +-------------+ +---------------+ +---------------+ |
  +---------------------|-----------------|--------------+     +-------------- ------|-----------------|--------------+  
                        |                 |                                          |                 | 
                   +----+-----+           |                                     +----------+           | 
                   |   vrf1   |-----------/                                     |   vrf2   |-----------/ 
                   | tbl 1100 |                                                 | tbl 1200 |
                   +----+-----+                                                 +----+-----+
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
- `br0`/`br1` — tenant L2 bridges; `tohost0`/`tohost1` are 802.1Q trunks to host0.
- `vxlan0`/`vxlan1` — L2VNI VTEPs (VNI = VLAN id: 10, 11, 20, 21).
- `vlanNN` SVIs — anycast gateways (`10.0.NN.1`, `2001:db8:0:NN::1`), enslaved to
  their VRF (`vlan10/11` → `vrf1`, `vlan20/21` → `vrf2`).
- `vlan1100`/`vlan1200` — L3VNI SVIs bound to `vrf1`/`vrf2`, on bridge `brl3`.
- `vxlanl3` — L3VNI VTEP (VNI 1100/1200) for routed (symmetric) traffic.

### Links (from `pe-lab.clab.yml`)

| A end          | B end          |
|----------------|----------------|
| host0:tope0    | pe0:tohost0    |
| host0:tope1    | pe0:tohost1    |
| pe0:tope       | pe1:tope       |
| pe1:tohost0    | host1:tope0    |
| pe1:tohost1    | host1:tope1    |

## Overlay details

Each host attaches to a PE over two physical links (`tope0`, `tope1`), each
carrying VLAN sub-interfaces that map to L2VNIs on the PE. The PEs stitch these
together across the core link using EVPN (VXLAN, UDP 4789).

| VRF   | L3VNI | PE SVI/L2VNIs (VLAN = VNI)          | Host subnets           |
|-------|-------|------------------------------------|------------------------|
| vrf1  | 1100  | pe0: 10, 11 — pe1: 10, 12          | `10.0.<vid>.0/24`, `2001:db8:0:<vid>::/64` |
| vrf2  | 1200  | pe0: 20, 21 — pe1: 20, 22          | `10.0.<vid>.0/24`, `2001:db8:0:<vid>::/64` |

- `tope0` → bridge `br0` → `vrf1` (VLANs 10/11 on pe0, 10/12 on pe1)
- `tope1` → bridge `br1` → `vrf2` (VLANs 20/21 on pe0, 20/22 on pe1)

Anycast gateways (`10.0.<vid>.1`, `2001:db8:0:<vid>::1`, MAC
`aa:bb:cc:00:00:<vid>`) live on every VTEP, so hosts use the same default
gateway regardless of which PE they are attached to.

Host addresses end in `.100` (host0) and `.101` (host1).
