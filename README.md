# OpenVPN

Servidor OpenVPN dockertizat per gestió de serveis interns a la infraestructura de sòcies.

> OpenVPN és una solució de connectivitat obtinguda a partir de programari: SSL (Secure Sockets Layer) VPN Virtual Private Network (xarxa virtual privada), OpenVPN ofereix connectivitat punt a punt amb validació jeràrquica d'usuaris i host connectats remotament, és una molt bona opció en tecnologies Wi-Fi (xarxes sense fils «IEEE 802.11») i permet utilitzar una gran configuració, entre les quals hi ha el balanç de càrrega. Està publicat sota la llicència GPL, de programari lliure.

https://ca.wikipedia.org/wiki/OpenVPN

Facilment configurable per als clients utiltizant un fitxer _.ovpn_ i el client oficinal de [OpenVPN](https://openvpn.net/client/).

## Configuració

Copia el fitxer _env.sample_ a _.env_.

```
$ cp env.sample .env
```

Edita el fitxer .env amb les teves variables

Finalment, pots iniciar el nou container.

```
$ docker compose up -d
```

Per revisar l'execució pots llegir els logs

```
$ docker compose logs -f
```

Per crear un nou client:

```
$ docker compose exec openvpn ovpn-new-client client_nou
```
Això mostrarà un fitxer ovpn per poder compartir amb el client amb les seves claus i la configuració.



## Variables d'entorn

Un exemple de fitxer __.env__:

```
EASYRSA_REQ_COUNTRY=ES
EASYRSA_REQ_PROVINCE=Barcelona
EASYRSA_REQ_CITY=Barcelona
EASYRSA_REQ_ORG=CommonsCloud
EASYRSA_REQ_EMAIL=system@commonscloud.coop
EASYRSA_REQ_OU=SomNuvol
EASYRSA_NO_PASS=1
EASYRSA_BATCH=1
EASYRSA_REQ_CN=somnuvol.coop

NETWORK=192.168.10.0
NETMASK=255.255.255.0
SERVER_NAME=vpn.somnuvol.coop
PUBLIC_IP=127.0.0.1
PUBLIC_PORT=1194

LDAP_URL=ldap://ldap1.example.org
LDAP_BIND_DN=uid=Manager,ou=People,dc=example,dc=com
LDAP_PASSWORD=SecretPassword
LDAP_BASE_DN="ou=People,dc=example,dc=com"
LDAP_SEARCH_FILTER="(&(uid=%u)(accountStatus=active))"
LDAP_GROUP_REQUIRE=false
LDAP_GROUP_BASE_DN="ou=Groups,dc=example,dc=com"
LDAP_GROUP_SEARCH_FILTER="(|(cn=developers)(cn=artists))"

#EXTRA_PARAMS=
#EXTRA_CLIENT_PARAMS=
```

La primera secció EASYRSA_* s'utilitza per generar els certicats el primer cop que s'executa l'aplicació.

La segona secció és la configuració de xarxa:

- NETWORK: Rang d'IPs de la xarxa interna que tindran els clients
- NETMASK: Netmask de la xarxa interna
- SERVER_NAME: Domini públic que tindrà l'accés al servidor VPN
- PUBLIC_IP: IP Pública per tenir accés al servidor VPN
- PUBLIC_PORT: Port d'accés al servidor VPN

La secció LDAP es opcional només en el cas que es vulgui autentica utilitzant user/password d'un servidor LDAP

I finalment:

- EXTRA_PARAM: Defineix paraments opcionals al fitxer de configuració del servidor VPN
- EXTRA_CLIENT_PARAMS: Defineix altres parámetres opcionals al fitxer de configuració del client.


## LDAP

Per gestionar usuàries per LDAP, necessitem tenir accés amb un usuari de només lectura per validar els UIDs a un servidor LDAP accesible des del container que té el servidor OpenVPN.

El filtre que utilitzem en aquest exemple es:

```
> ldapsearch -vvv -H ldap://lldap:3890 -b "dc=somnuvol,dc=coop" -D "cn=nobody,ou=people,dc=somnuvol,dc=coop" -W "((uid=nobody))"
```

Que farà referència al filter que utilitzem a les variables d'entorn LDAP_SEARCH_FILTER.

Per poder gestionar un petit nombre d'usuàries, es possible utilitzar per exemple LLDAP.

Una possible configuració de docker-compose.yml:

```
volumes:
  data:
  lldap_data:
    driver: local

services:
  openvpn:
    image: somnuvol/openvpn
    devices:
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
      - MKNOD
    ports:
      - 943:943
      - 4443:443
      - 1194:1194/udp
    volumes:
      - data:/openvpn
    env_file:
      - .env
    restart: unless-stopped
    environment:
      EXTRA_PARAMS: |
        push "dhcp-option DNS 192.168.1.5"
        push "block-outside-dns"
        push "route 192.168.1.5 255.255.255.255"
        push "route 192.168.1.9 255.255.255.255"
        push "route 192.168.1.15 255.255.255.255"
  lldap:
    image: lldap/lldap:stable
    ports:
      - "17170:17170"
    volumes:
      - "lldap_data:/data"
    environment:
      - UID=1001
      - GID=1001
      - TZ=Europe/Andorra
      - LLDAP_JWT_SECRET=secretkey
      - LLDAP_KEY_SEED=secretseed
      - LLDAP_LDAP_BASE_DN=dc=somnuvol,dc=coop
      - LLDAP_LDAP_USER_PASS=passwordsecret
```

I un fitxer de configuració:

```
EASYRSA_REQ_COUNTRY=ES
EASYRSA_REQ_PROVINCE=Barcelona
EASYRSA_REQ_CITY=Barcelona
EASYRSA_REQ_ORG=CommonsCloud
EASYRSA_REQ_EMAIL=system@commonscloud.coop
EASYRSA_REQ_OU=SomNuvol
EASYRSA_NO_PASS=1
EASYRSA_BATCH=1
EASYRSA_REQ_CN=somnuvol.coop

NETWORK=192.168.10.0
NETMASK=255.255.255.0
SERVER_NAME=vpn.somnuvol.coop
PUBLIC_IP=127.0.0.1
PUBLIC_PORT=1194

LDAP_URL=ldap://lldap:3890
LDAP_BIND_DN=uid=nobody,ou=People,dc=somnuvol,dc=coop
LDAP_PASSWORD=SecretPassword
LDAP_BASE_DN="ou=People,dc=nobody,dc=coop"
LDAP_SEARCH_FILTER="(uid=%u)"
LDAP_GROUP_REQUIRE=false
```

## Configuració d'accés a altres xarxes internes

Per facilitar l'accés a altres xarxes accesibles per el servidor OpenVPN, podem utilitzar les opcions de OpenVPN per fer push d'algunes rutes.

Per fer-ho podem utilitzar la variable EXTRA_PARAMS per ampliar la configuració d'aquesta manera:

```
EXTRA_PARAMS: |
        push "dhcp-option DNS 192.168.1.5"
        push "block-outside-dns"
        push "route 192.168.1.5 255.255.255.255"
        push "route 192.168.1.9 255.255.255.255"
        push "route 192.168.1.15 255.255.255.255"
```

## Creació del fitxer OVPN

Facilitem la generació de nous client utilitzant l'script __ovpn-new-client__

Després de tenir el servidor OpenVPN en funcionament, podem generar les claus i la configuració del nou client:

```
> docker compose exec openvpn ovpn-new-client socia1 > socia1.ovpn
```

Al fitxer _socia1.ovpn_ tindrem els certificats, les claus i totes les dades necesàries per accedir a la VPN. Aquest fitxer, es pot obrir directament amb el client de OpenVPN i tindriem configurat al client per accedir a la nova xarxa.

En el cas de tenir habilitada la gestió amb LDAP, hauriem de crear també el nou usuari/pass al servidor LDAP per al nou client.

## Crèdits

Equip tècnic de SomNúvol - Luca Rullo - suport@somnuvol.coop - https://somnuvol.coop
