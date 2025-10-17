FROM ubuntu:24.04

LABEL org.opencontainers.image.authors="luca@femprocomuns.coop"

ENV TZ="Europe/Andorra"

ARG DEBIAN_FRONTEND="noninteractive"

RUN apt update && apt upgrade -y

RUN apt install -y openvpn easy-rsa openvpn-auth-ldap ldap-utils iproute2 iptables

WORKDIR /openvpn

RUN make-cadir /openvpn/easy-rsa

COPY entrypoint.sh /entrypoint.sh

COPY ovpn-new-client /usr/local/sbin/ovpn-new-client

ENTRYPOINT ["/entrypoint.sh"]

CMD ["openvpn","server.conf"]

EXPOSE 1194/udp
