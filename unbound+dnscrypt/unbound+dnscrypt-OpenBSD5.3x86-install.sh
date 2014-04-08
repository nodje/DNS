#!/bin/sh

# install unbound
pkg_add -i ftp://ftp.openbsd.org/pub/OpenBSD/5.3/packages/amd64/unbound-1.4.19p0.tgz
#create a syslog socket in the unbound chroot
sh -c 'echo syslogd_flags=\"\${syslogd_flags} -a /var/unbound/dev/log\" >> /etc/rc.conf.local'
#because it is chrooted, so that unbound.log can be created
mkdir /var/unbound/var/log
#config unbound
#cf. https://calomel.org/unbound_dns.html
#Step 1, root-hints
#Download a copy of the root hints from Internic and place it in the /var/unbound/etc/root.hints file. 
#This file will be called by the root-hints: directive in the unbound.conf file.
#ftp.internic.net poisoned by GFW, replace by IP address
#wget ftp://FTP.INTERNIC.NET/domain/named.cache -O /var/unbound/etc/root.hints
mkdir -p /var/unbound/etc && wget ftp://192.0.32.9/domain/named.cache -O /var/unbound/etc/root.hints
#Step 2, auto-trust-anchor-file

#config file
cat << EOF | sudo tee /var/unbound/etc/unbound.conf
## Simple Authoritative recursive caching DNS server config for Sinapolis Lan
#
server:
    interface: 0.0.0.0
    access-control: 127.0.0.0/8 allow
    access-control: 192.168.0.0/16 allow
    verbosity: 1
    logfile: "/var/unbound/var/log/unbound.log"
    port: 53
    root-hints: "/var/unbound/etc/root.hints"
    hide-identity: yes
    hide-version: yes
    cache-min-ttl: 3600
    prefetch: yes
    num-threads: 2
  ## Unbound Optimization and Speed Tweaks ###
    
  # the number of slabs to use for cache and must be a power of 2 times the
  # number of num-threads set above. more slabs reduce lock contention, but
  # fragment memory usage.
    msg-cache-slabs: 4
    rrset-cache-slabs: 4
    infra-cache-slabs: 4
    key-cache-slabs: 4
    rrset-cache-size: 64m
    msg-cache-size: 32m
  ## Unbound Optimization and Speed Tweaks ###
    
    private-address: 10.0.0.0/8
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/16
    private-address: 192.254.0.0/16
    private-address: 192.168.0.0/16
    
  # Allow the domain (and its subdomains) to contain private addresses.
  # local-data statements are allowed to contain private addresses too.
    private-domain: "home.lan"

    unwanted-reply-threshold: 10000
    do-not-query-localhost: no
    val-clean-additional: yes

  # Blocking Ad Server domains from http://pgl.yoyo.org/as/serverlist.php?hostformat=hosts&mimetype=plaintext
  # local-zone: "doubleclick.net" redirect
  # local-data: "doubleclick.net A 127.0.0.1"
    include: /var/unbound/etc/ad_servers

  # locally served zones can be configured for the machines on the LAN.
    local-zone: "home.lan." static

    local-data: "router.home.lan.		IN A 192.168.0.1"
    local-data: "xiaomi2.home.lan.		IN A 192.168.0.8"
    local-data: "dns.home.lan.			IN A 192.168.0.18"
    local-data: "poste5.home.lan.		IN A 192.168.0.20"
    local-data: "dhcp5.home.lan.		IN A 192.168.0.5"
    local-data: "dhcp6.home.lan.		IN A 192.168.0.6"
    local-data: "dhcp7.home.lan.		IN A 192.168.0.7"

    local-data-ptr: "192.168.0.1		router.home.lan"
    local-data-ptr: "192.168.0.8		xiaomi2.home.lan"
    local-data-ptr: "192.168.0.18		dns.home.lan"
    local-data-ptr: "192.168.0.20		poste5.home.lan"
    local-data-ptr: "192.168.0.5		dhcp5.home.lan"
    local-data-ptr: "192.168.0.6		dhcp6.home.lan"
    local-data-ptr: "192.168.0.7		dhcp7.home.lan"

forward-zone:
    name: "."
    forward-addr: 127.0.0.1@40      # local dnscrypt daemon
    forward-first: no
EOF
#create yoyo adserver fetching script
cat << EOF | sudo tee /var/unbound/etc/getAdServersList.sh
#!/bin/sh
#
# Convert the Yoyo.org anti-ad server listing
# into an unbound dns spoof redirection list.

/usr/local/bin/wget -O /var/unbound/etc/yoyo_ad_servers "http://pgl.yoyo.org/as/serverlist.php?hostformat=hosts&mimetype=plaintext" && \\
cat /var/unbound/etc/yoyo_ad_servers | grep 127 | awk '{print \$2}' | \\
while read line ; \\
 do \\
   echo "local-zone: \"\$line\" redirect" ;\\
   echo "local-data: \"\$line A 127.0.0.1\"" ;\\
 done > \\
/var/unbound/etc/ad_servers
EOF
chmod +x /var/unbound/etc/getAdServersList.sh
#schedule the job and backup current user crontab before
crontab -l > crontab.backup
crontab -l | awk '{print} END {print "#do daily update of ad-servers for unbound\
00      12      *       *       *       /var/unbound/etc/getAdServersList.sh"}' | crontab -

#create unbound start script
cat << EOF | sudo tee /etc/rc.d/unbound
#!/bin/sh
#
# unbound domain name server
#

daemon="/usr/local/sbin/unbound"
daemon_flags=""
. /etc/rc.d/rc.subr
rc_cmd \$1
EOF
#start daemon
/etc/rc.d/unbound start
#downlaod libsodium
wget https://download.libsodium.org/libsodium/releases/libsodium-0.4.5.tar.gz
#install libsodium
tar xzf libsodium-0.4.5.tar.gz
cd libsodium-0.4.5
./configure
make
make install
cd ..
rm -rf libsodium-*
#download dnscrypt
wget http://download.dnscrypt.org/dnscrypt-proxy/dnscrypt-proxy-1.3.3.tar.bz2
#install dnscrypt
bunzip2 -cd dnscrypt-proxy-*.tar.bz2 | tar xf -
cd dnscrypt-proxy-1.3.3
./configure && make -j2
make install
cd ..
rm -rf dnscrypt-proxy-*
#create dnscrypt user to run the process
useradd -m dnscrypt
#create dameon script
#config cf. http://dnscrypt.org/
cat << EOF | sudo tee /etc/rc.d/dnscrypt-proxy
#!/bin/sh
#
# dnscryptproxy daemon
#
daemon="/usr/local/sbin/dnscrypt-proxy"
daemon_flags="--user=dnscrypt --local-address=127.0.0.1:40 --resolver-address=106.186.17.181:2053 --provider-name=2.dnscrypt-cert.ns2.jp.dns.opennic.glue --provider-key=8768:C3DB:F70A:FBC6:3B64:8630:8167:2FD4:EE6F:E175:ECFD:46C9:22FC:7674:A1AC:2E2A --edns-payload-size=4096 --daemonize"
. /etc/rc.d/rc.subr
rc_cmd \$1
EOF
#TEMPORARY, until dnscrypt daemon works
sh -c 'echo /usr/local/sbin/dnscrypt-proxy --user=dnscrypt --local-address=127.0.0.1:40 --resolver-address=106.186.17.181:2053 --provider-name=2.dnscrypt-cert.ns2.jp.dns.opennic.glue --provider-key=8768:C3DB:F70A:FBC6:3B64:8630:8167:2FD4:EE6F:E175:ECFD:46C9:22FC:7674:A1AC:2E2A --edns-payload-size=4096 --daemonize >>/etc/rc.local'
#start dnscrypt
. /etc/rc.local
#/etc/rc.d/dnscrypt-proxy start
#make things permanent
#sh -c 'echo pkg_scripts=\"dnscrypt-proxy unbound\" >> /etc/rc.conf.local'
sh -c 'echo pkg_scripts=\"unbound\" >> /etc/rc.conf.local'
echo "You've been provisioned"
