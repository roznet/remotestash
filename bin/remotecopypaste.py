#!/usr/bin/env python3

from zeroconf import ServiceBrowser, Zeroconf
import socket

class MyListener:

    def remove_service(self, zeroconf, type, name):
        print( f'Service {name} removed' )

    def add_service(self, zeroconf, type, name):
        info = zeroconf.get_service_info(type, name)
        ip = socket.inet_ntoa(info.addresses[0])
        print( f'Service {info.name} added, connecting to: {ip}:{info.port}')
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect( (ip,info.port ) )
            text = b'hello'
            s.sendall( len(text).to_bytes(8, byteorder = 'little') )
            s.sendall( text )
            length = int.from_bytes( s.recv( 8 ), byteorder='little' )
            print( f'length {length}')
            msg = s.recv( length )
            print( msg )
            

        
zeroconf = Zeroconf()
listener = MyListener()
browser = ServiceBrowser(zeroconf, "_remotecopypaste._tcp.local.", listener)
try:
    input("Press enter to exit...\n\n")
finally:
    zeroconf.close()
