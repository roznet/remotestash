#!/usr/bin/env python3

from zeroconf import ServiceBrowser, Zeroconf, ServiceInfo
import socket
from contextlib import closing
import time
import argparse
from http.server import BaseHTTPRequestHandler
from http.server import HTTPServer
from urllib import parse
from requests import Session, Request

class Listener:

    def remove_service(self, zeroconf, type, name):
        print( f'Service {name} removed' )

    def add_service(self, zeroconf, type, name):
        info = zeroconf.get_service_info(type, name)
        self.ip = socket.inet_ntoa(info.addresses[0])
        self.port = info.port
        self.info = info
        print( f'Found Service {info.name} added, connecting to: {self.ip}:{self.port}')
        self.session = Session()
        ip = self.ip
        port = self.port
        response = self.session.get( f'http://{ip}:{port}/yo' )
        print( response )
        exit()

class Advertiser:
    def __init__(self):
        self.ip = self.get_ip()
        self.port = self.get_port()
        
    def get_ip(self):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            # doesn't even have to be reachable
            s.connect(('10.255.255.255', 1))
            IP = s.getsockname()[0]
        except:
            IP = '127.0.0.1'
        finally:
            s.close()
        return IP

    def get_port(self):
        with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
            s.bind(('', 0))
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            return s.getsockname()[1]
    
    def start_advertisement(self,name):
        self.info = ServiceInfo(
            "_remotecopypaste._tcp.local.",
            "remotecopy http {}._remotecopypaste._tcp.local.".format(name),
            addresses=[socket.inet_aton(self.ip)],
            port=self.port,
            properties={"type": "remotecopy_device"},
        )

        zeroconf = Zeroconf()
        zeroconf.register_service(self.info)

    def clean_advertisement(self):
        zeroconf.unregister_service(self.info)
        zeroconf.close() 
    
class GetHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        parsed_path = parse.urlparse(self.path)
        message_parts = [
            'CLIENT VALUES:',
            'client_address={} ({})'.format(
                self.client_address,
                self.address_string()),
            'command={}'.format(self.command),
            'path={}'.format(self.path),
            'real path={}'.format(parsed_path.path),
            'query={}'.format(parsed_path.query),
            'request_version={}'.format(self.request_version),
            '',
            'SERVER VALUES:',
            'server_version={}'.format(self.server_version),
            'sys_version={}'.format(self.sys_version),
            'protocol_version={}'.format(self.protocol_version),
            '',
            'HEADERS RECEIVED:',
        ]
        for name, value in sorted(self.headers.items()):
            message_parts.append(
                '{}={}'.format(name, value.rstrip())
            )
        message_parts.append('')
        message = '\r\n'.join(message_parts)
        self.send_response(200)
        self.send_header('Content-Type',
                         'text/plain; charset=utf-8')
        self.end_headers()
        self.wfile.write(message.encode('utf-8'))
        
class Driver :
    def __init__(self,args=None):
        self.args = args
        self.verbose = True;

    def cmd_listen(self):
        zeroconf = Zeroconf()
        listener = Listener()
        browser = ServiceBrowser(zeroconf, "_remotecopypaste._tcp.local.", listener)
        time.sleep(0.1)

    def cmd_serve(self):
        zeroconf = Zeroconf()
        advertiser = Advertiser()
        advertiser.start_advertisement('brice')
        server = HTTPServer((advertiser.ip, advertiser.port), GetHandler)
        print(f'Starting server on {advertiser.ip}:{advertiser.port}, use <Ctrl-C> to stop')
        try:
            while True:
                print( 1 )
                server.handle_request()
        finally:
            Advertiser.clean_advertisement()

        
if __name__ == "__main__":
                
    commands = {
        'listen':{'attr':'cmd_listen','help':'listen for server'},
        'serve':{'attr':'cmd_serve','help':'start server'},
    }
    
    description = "\n".join( [ '  {}: {}'.format( k,v['help'] ) for (k,v) in commands.items() ] )
    
    parser = argparse.ArgumentParser( description='Remote Copy', formatter_class=argparse.RawTextHelpFormatter )
    parser.add_argument( 'command', metavar='Command', help='command to execute:\n' + description)
    parser.add_argument( '-v', '--verbose', action='store_true', help='verbose output' )
    args = parser.parse_args()

    command = Driver(args)

    if args.command in commands:
        getattr(command,commands[args.command]['attr'])()
    else:
        print( 'Invalid command "{}"'.format( args.command) )
        parser.print_help()
