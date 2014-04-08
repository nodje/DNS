DNS
===

Setup your own DNS server as a local cache + forwarding server for your organisation
Forward securely with dnscryptproxy to the closest/fastest DNS Server

This setup was design primarily for usage in China, where DNS poisoning is just part of the internet. It's probably the easiest of the pieces that compose the Great Firewall of China (http://www.greatfirewallofchina.org/).
By setting this up for your local LAN, you'll get proper DNS resolution. (Use DNSSEC if you want a higher level of protection against poisoning) 
On it's own it's not going to let you access websites that are blocked further up by other more elaborated GFC pieces, but it'll help support local proxies you may use, secured tunnels or the likes.
Proxy usage config vary greatly between apps & platforms. Some apps proxy DNS resolution some not. It's hard to tell sometimes, especially on smartphones and tablets. I've found that apps that were not able to function in China, even when using proxied secured tunneled, would finally function properly with non poisoned DNS resolution.

This could be particularly useful for people residing in countries were internet is censored. Bear in mind that DNS poisoning is really easy to achieve, and is probably the most basic technic used to censor.

The setup is also an example of a caching resolving, and ad server blocking DNS server. It will speed up your internet access sensibly, even if you live in a country with a good network infrastructure. If you don't live in a place were DNS are being manipulated, you may want to disable dnscrypt-proxy usage, which is probably slower than your provider's DNS. (You can consider using it for privacy also)


If you want to use this script:
1) visit http://dnscrypt.org/ and identify which DNSCrypt-enabled resolver is closest to your location or is the more appropriate for your needs, and replace 
--resolver-address
--provider-name
--provider-key
2)install vagrant
3)review and copy VagrantFile in a new directory that is going to be your vagrant base for this virtual machine


Known problems:
1) dnscryptproxy can't be started as a OpenDNS daemon the regular way. There's an error message I can't understand. 
Startup is done with a command line in /etc/rc.local
See https://github.com/jedisct1/dnscrypt-proxy/issues/77

Reference:
https://calomel.org/unbound_dns.html
http://dnscrypt.org/
