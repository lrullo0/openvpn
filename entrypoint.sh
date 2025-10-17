#!/bin/bash

set -e

if [ ! -v SERVER_NAME ]; then
echo "SERVER_NAME var required"
exit 0
fi 


if [ ! -c /dev/net/tun ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
fi

cd /openvpn/easy-rsa

if [ ! -f /openvpn/ca.crt ]; then
echo "Generate new config"
./easyrsa init-pki
./easyrsa build-ca
cp pki/ca.crt /openvpn/
fi


if [ ! -f  /openvpn/dh.pem ]; then
echo "Generate new server cert"
./easyrsa gen-req $SERVER_NAME nopass
./easyrsa gen-dh
./easyrsa sign-req server $SERVER_NAME
cp pki/dh.pem pki/issued/$SERVER_NAME.crt pki/private/$SERVER_NAME.key /openvpn/
fi

cd /openvpn/
if [ ! -f ta.key ]; then
openvpn --genkey secret ta.key
fi

cat <<EOF >server.conf
port $PUBLIC_PORT
proto udp
dev tun
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key  # This file should be kept secret
dh dh.pem
server $NETWORK $NETMASK
ifconfig-pool-persist ipp.txt
client-to-client
keepalive 10 120
tls-auth ta.key 0 # This file is secret
allow-compression yes
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
auth-gen-token 0
EOF

if [ -v LDAP_URL ]; then

## Start LDAP Config
## ref: https://github.com/threerings/openvpn-auth-ldap/wiki/Configuration

cat <<EOF >>server.conf
plugin /usr/lib/openvpn/openvpn-auth-ldap.so "/openvpn/ldap.conf"
EOF

cat <<EOF >/openvpn/ldap.conf
<LDAP>
URL $LDAP_URL
BindDN $LDAP_BIND_DN
Password $LDAP_PASSWORD
Timeout 15
TLSEnable no
FollowReferrals yes
</LDAP>

<Authorization>
BaseDN $LDAP_BASE_DN
SearchFilter $LDAP_SEARCH_FILTER
RequireGroup false
#RequireGroup $LDAP_GROUP_REQUIRE
EOF

if [ -v LDAP_GROUP_BASE_DN ]; then
cat <<EOF >>/openvpn/ldap.conf
<Group>
BaseDN $LDAP_GROUP_BASE_DN
SearchFilter $LDAP_GROUP_SEARCH_FILTER
MemberAttribute "member"
</Group>
EOF
fi

cat <<EOF >>/openvpn/ldap.conf
</Authorization>
EOF

else

sed -i '/^plugin \/usr\/lib\/openvpn.*/d' server.conf

fi
## end LDAP Config

## Extra PARAMs
if [ -v EXTRA_PARAMS ]; then
cat <<EOF >>server.conf
$EXTRA_PARAMS
EOF
fi

## Configure iptables before start

iptables -t nat -A POSTROUTING -s $NETWORK/$NETMASK -o eth0 -j MASQUERADE

exec "$@"
