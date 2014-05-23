#!/usr/bin/env python


import sys

import dns.update
import dns.query
import dns.tsigkeyring

#
# Replace the keyname and secret with appropriate values for your
# configuration.
#
keyring = dns.tsigkeyring.from_text({
    'update.zones.key' : 'z6z4X6TZ/1zsazWf7oT1AA=='
    })

#
# Replace "example." with your domain, and "host" with your hostname.
#
update = dns.update.Update('example.vip.com', keyring=keyring)
update.replace('test11', 300, 'A', sys.argv[1])

#
# Replace "10.0.0.1" with the IP address of your master server.
#
response = dns.query.tcp(update, 'localhost', timeout=10)