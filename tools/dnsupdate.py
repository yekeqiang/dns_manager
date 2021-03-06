#!/usr/bin/env python2.7
# DNS management tool
# Manage DNS using DDNS features
#
# Usage: python dnsupdate.py -s server -k key add foo.example.com 300 a 1.2.3.4
# -h HELP!
# -s the server
# -k the key
# the action (add, delete, replace) and record specific parameters

import argparse 
import textwrap
import re
import dns.query
import dns.tsigkeyring
import dns.update
import dns.reversename
import dns.resolver
from dns.exception import DNSException, SyntaxError

Verbose = False
#
# Let's use argparser!
def getArgs():
    # Setup a argument parser to collect the values we need
    Args = argparse.ArgumentParser(usage='%(prog)s [-h] {-s} {-k} {-o} [-x] {add|delete|update} {Name} {TTL} [IN] {Type} {Target}', description='Add, Delete, Replace DNS records using DDNS.')

    # -s - The Server
    Args.add_argument('-s', dest='Server', required=True, 
                      help='DNS server to update (Required)')

    # -k - The Key
    Args.add_argument('-k', dest='Key', required=True, 
                      help='TSIG key. The TSIG key file should be in DNS KEY record format. (Required)')
 
    # -o - The Origin
    Args.add_argument('-o', dest='Origin', required=False,
                      help='Specify the origin. Optional, if not provided origin will be determined')

    # -x - Add Reverse?
    Args.add_argument('-x', dest='doPTR', action='store_true', 
                      help='Also modify the PTR for a given A or AAAA record. Forward and reverse zones must be on the same server.')

    # -v - Add Reverse?
    Args.add_argument('-v', dest='Verbose', action='store_true',
                      help='Print the rcode returned with for each update')

    # myInput is a list of additional values required. Actual data varies based on action
    Args.add_argument('myInput', action='store', nargs='+', metavar='add|delete|update', 
                       help='{hostname} {TTL} [IN] {Type} {Target}.')

    myArgs = Args.parse_args()
    return myArgs

#
# Is a valid TTL?
def isValidTTL(TTL):
    try:
        TTL = dns.ttl.from_text(TTL)
    except:
        print 'TTL:', TTL, 'is not valid'
        exit()
    return TTL
#
# Is a Valid PTR?
def isValidPTR(ptr):
    if re.match(r'\b(?:\d{1,3}\.){3}\d{1,3}.in-addr.arpa\b', ptr):
        return True
    else:
        print 'Error:', ptr, 'is not a valid PTR record'
        exit() 
#
# Is a valid IPV4 address?
def isValidV4Addr(Address):
    try:
        dns.ipv4.inet_aton(Address)
    except socket.error:
        print 'Error:', Address, 'is not a valid IPv4 address'
        exit()
    return True
#
# Is a valid IPv6 address?
def isValidV6Addr(Address):
    try:
        dns.ipv6.inet_aton(Address) 
    except SyntaxError:
        print 'Error:', Address, 'is not a valid IPv6 address'
        exit()
    return True

def isValidName(Name):
    if re.match(r'^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9]\.?)$', Name):
        return True
    else:
        print 'Error:', Name, 'is not a valid name'
        exit()

def verifymyInput(myInput):
    # if the Class is defined (e.g. IN) strip it out
    if myInput[3].upper() == 'IN':
        myInput.pop(3) 
    # Validate the host and domain name syntax
    # We're going to make sure that the action and arguments in MymyInput are valid
    action = myInput[0].lower()
    if action != 'add' and action != 'delete' and action != 'del' and action != 'update':
        print 'Error: Invalid action'
        print 'Usage: dnsupdate -s server -k key [add|delete|update] [Name] [Type] [TTL] [Address]'
        exit()
    # Set the TTL
    ttl = isValidTTL(myInput[2])
    # We need to know type in order to do some tests so we'll define it here
    type = myInput[3].upper()
    # Based on the type of record we're trying to update we'll run some tests
    if type == 'A' or type == 'AAAA':
        if len(myInput) < 5:
            print 'Error: not enough options for an A record'
            print 'Usage: dnsupdate -o origin -s server -k key add|delete|update Name TTL A Address'
            exit()
        isValidName(myInput[1])
        if type == 'A':
            isValidV4Addr(myInput[4])
        elif type == 'AAAA':
            isValidV6Addr(myInput[4])
    if type == 'CNAME' or type == 'NS':
        if len(myInput) < 4:
            print 'Error: not enough options for a CNAME record'
            print 'Usage: dnsupdate -o origin -s server -k key add|delete|update Name TTL CNAME Target'
            exit()
        isValidName(myInput[1])
        isValidName(myInput[4])
    if type == 'PTR':
        if len(myInput) < 4:
            print 'Error: not enough options for a PTR record'
            print 'Usage: dnsupdate -o origin -s server -k key add|delete|update Name TTL PTR Target'
            exit()
#        isValidPTR(myInput[1])
        isValidName(myInput[4])
    if type == 'TXT':
        # Wrap the TXT string in quotes since the quotes get stripped 
        myInput[4] = '"%s"' % myInput[4]
    if type == 'MX':
        if len(myInput) < 4:
            print 'Error: not enough options for an MX record'
            print 'Usage: dnsupdate -o origin -s server -k key add|delete|update Name TTL MX Weight Target'
        if int(myInput[4]) > 65535 or int(myInput[4]) < 0:
            print 'Error: Preference must be between 0 - 65535'
            exit()
        isValidName(myInput[1])
        isValidName(myInput[5])
    if type == 'SRV':
        if len(myInput) < 7:
            print 'Error: not enough options for a SRV record'
            print 'Usage: dnsupdate -o origin -s server -k key add|delete|update Name TTL SRV Priority Weight Port Target'
        if int(myInput[4]) > 65535 or int(myInput[4]) < 0:
            print 'Error: Priority must be between 0 - 65535'
            exit()
        if int(myInput[5]) > 65535 or int(myInput[5]) < 0:
            print 'Error: Weight must be between 0 - 65535'
            exit()
        if int(myInput[6]) > 65535 or int(myInput[6]) < 0:
            print 'Error: Port must be between 0 - 65535'
            exit()
        isValidName(myInput[1])
        isValidName(myInput[7])
    return action, ttl, type

def getKey(FileName):
    f = open(FileName)
    key = f.readline()
    f.close()
    k = {key.rsplit(' ')[0]:key.rsplit(' ')[6]}
    try:
        KeyRing = dns.tsigkeyring.from_text(k)
    except:
        print k, 'is not a valid key. The file should be in DNS KEY record format. See dnssec-keygen(8)'
        exit()
    return KeyRing

def genPTR(Address):
    try:
        a = dns.reversename.from_address(Address)
    except:
        print 'Error:', Address, 'is not a valid IP adresss'
    return a
    
def parseName(Origin, Name):
    try:
        n = dns.name.from_text(Name)
    except:
        print 'Error:',  n, 'is not a valid name'
        exit()
    if Origin is None:
        Origin = dns.resolver.zone_for_name(n)
        Name = n.relativize(Origin)
        return Origin, Name
    else:
        try:
            Origin = dns.name.from_text(Origin)
        except:
            print 'Error:',  Name, 'is not a valid origin'
            exit()
        Name = n - Origin
        return Origin, Name

def doUpdate(Server, KeyFile, Origin, doPTR, myInput):
    # Sanity check the data and get the action and record type 
    Action, TTL, Type = verifymyInput(myInput)
    # Get the hostname and the origin
    Origin, Name = parseName(Origin, myInput[1])
    # Validate and setup the Key
    KeyRing = getKey(KeyFile)
    # Start constructing the DDNS Query
    Update = dns.update.Update(Origin, keyring=KeyRing)
    # Put the payload together. 
    if Type == 'A' or Type == 'AAAA':
        myPayload = myInput[4]
        if doPTR == True:
            ptrTarget = Name.to_text() + '.' + Origin.to_text()
            ptrOrigin, ptrName = parseName(None, genPTR(myPayload).to_text())
            ptrUpdate = dns.update.Update(ptrOrigin, keyring=KeyRing)
    if Type == 'CNAME' or Type == 'NS' or Type == 'TXT' or Type == 'PTR':
        myPayload = myInput[4]
        do_PTR = False
    elif Type == 'SRV':
        myPayload = myInput[4]+' '+myInput[5]+' '+myInput[6]+' '+myInput[7]
        do_PTR = False
    elif Type == 'MX':
        myPayload = myInput[4]+' '+myInput[5]
        do_PTR = False
    # Build the update
    if Action == 'add':
        Update.add(Name, TTL, Type, myPayload)
        if doPTR == True:
            ptrUpdate.add(ptrName, TTL, 'PTR', ptrTarget)
    elif Action == 'delete' or Action == 'del':
        Update.delete(Name, Type, myPayload)
        if doPTR == True:
            ptrUpdate.delete(ptrName, 'PTR', ptrTarget)
    elif Action == 'update':
        Update.replace(Name, TTL, Type, myPayload)
        if doPTR == True:
            ptrUpdate.replace(ptrName, TTL, 'PTR', ptrTarget)
    # Do the update
    try:
        Response = dns.query.tcp(Update, Server)
    except dns.tsig.PeerBadKey:
        print 'ERROR: The server is refusing our key'
        exit()
    if Verbose == True:
         print 'Creating', Type, 'record for', Name, 'resulted in:', dns.rcode.to_text(Response.rcode())
    if doPTR == True:
        try:
            ptrResponse = dns.query.tcp(ptrUpdate, Server)
        except dns.tsig.PeerBadKey:
            print 'ERROR: The server is refusing our key'
            exit()
        if Verbose == True:
            print 'Creating PTR record for', Name, 'resulted in:', dns.rcode.to_text(Response.rcode())

def main():
    myArgs = getArgs()
    global Verbose
    if myArgs.Verbose == True:
        Verbose = True
    doUpdate(myArgs.Server, myArgs.Key, myArgs.Origin, myArgs.doPTR, myArgs.myInput)

main()