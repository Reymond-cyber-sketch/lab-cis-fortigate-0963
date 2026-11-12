# 2026-11-12 19:52:02 by RouterOS 7.23.7
# system id = F8Hy77PeUWO
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no name=ether7
set [ find default-name=ether2 ] disable-running-check=no name=ether8
set [ find default-name=ether3 ] disable-running-check=no name=ether9
set [ find default-name=ether4 ] disable-running-check=no name=ether10
set [ find default-name=ether5 ] disable-running-check=no name=ether11
set [ find default-name=ether6 ] disable-running-check=no name=ether12
/ip address
add address=198.51.100.97/30 comment="WAN hacia FGT-USER" interface=ether7 network=198.51.100.96
add address=203.0.113.97/30 comment="WAN hacia VPN-PEER" interface=ether8 network=203.0.113.96
/ip dhcp-client
add interface=ether10 name=client1
/ip firewall nat
add action=masquerade chain=srcnat out-interface=ether10
/system identity
set name=ISP
