# 2026-11-12 19:56:03 by RouterOS 7.23.7
# system id = mi/SrKE4NDM
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
set [ find default-name=ether6 ] disable-running-check=no
/interface vlan
add interface=ether2 name=VLAN10-USERS vlan-id=10
add interface=ether2 name=VLAN20-ADMIN vlan-id=20
/ip pool
add name=POOL-VLAN10 ranges=10.24.96.10-10.24.96.120
add name=POOL-VLAN20 ranges=10.24.97.10-10.24.97.120
/ip address
add address=10.10.10.2/30 comment="TRANSITO HACIA FORTIGATE" interface=ether1 network=10.10.10.0
add address=10.24.96.1/25 comment="GATEWAY VLAN10" interface=VLAN10-USERS network=10.24.96.0
add address=10.24.97.1/25 comment="GATEWAY VLAN20" interface=VLAN20-ADMIN network=10.24.97.0
/ip dhcp-server
add address-pool=POOL-VLAN10 interface=VLAN10-USERS lease-time=1h name=DHCP-VLAN10
add address-pool=POOL-VLAN20 interface=VLAN20-ADMIN lease-time=1h name=DHCP-VLAN20
/ip dhcp-server network
add address=10.24.96.0/25 dns-server=8.8.8.8,1.1.1.1 gateway=10.24.96.1
add address=10.24.97.0/25 dns-server=8.8.8.8,1.1.1.1 gateway=10.24.97.1
/ip dns
set allow-remote-requests=yes servers=8.8.8.8,1.1.1.1
/ip route
add dst-address=0.0.0.0/0 gateway=10.10.10.1
/system identity
set name=USER-ROUTER
