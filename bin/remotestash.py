#!/usr/bin/env python3

from zeroconf import ServiceBrowser, Zeroconf, ServiceInfo
import hashlib
import urllib3
import ssl
import socket
import os
from contextlib import closing
import time
import argparse
from http.server import BaseHTTPRequestHandler
from http.server import HTTPServer
from urllib import parse
from requests import Session, Request
import pwd
import json
import sys
from pprint import pprint

def file_hash(filepath):
    openedFile = open(filepath)
    readFile = openedFile.read()

    hash = hashlib.sha1(readFile.encode('utf-8'))
    return hash.hexdigest()

def content_hash(content):
    if isinstance(content,str):
        data = content.encode('utf-8')
    else:
        data = content
    hash = hashlib.sha1(data)
    return hash.hexdigest()

class Stash:
    def __init__(self,args):
        self.args = args
        if 'dir' in self.args:
            self.location = self.args['dir']
        else:
            self.location = os.path.expanduser("~/.remotestash")
        self.content_file = os.path.join( self.location, 'contents.json' )
        if os.path.isfile( self.content_file ):
            with open( self.content_file ) as jf:
                self.contents = json.load( jf )
        else:
            self.contents = {'items':[]}

    def pull(self):
        if len(self.contents['items']):
            item = self.contents['items'].pop()
            datafile = os.path.join( self.location, item['file'] )
            data = None
            if os.path.isfile( datafile ):
                with open(datafile, 'r' ) as readf:
                    data = readf.read()
                os.remove(datafile)
            self.save_content()
            return data

        return None
    
    def last(self):
        if len(self.contents['items']):
            item = self.contents['items'][-1]
            datafile = os.path.join( self.location, item['file'] )
            data = None
            if os.path.isfile( datafile ):
                with open(datafile, 'r' ) as readf:
                    data = readf.read()
            return data

        return ''

    def push(self,name,data):
        item = { 'name': name, 'file': content_hash( data ) }

        with open( os.path.join( self.location, item['file'] ), 'wb' if isinstance(data,bytes) else 'w' ) as of:
            of.write( data )
        self.contents['items'].append( item )
        self.save_content()

    def save_content(self):
        with open( self.content_file, 'w' ) as jf:
            json.dump( self.contents, jf )

class Listener:

    def __init__(self,cmd,args):
        self.cmd = cmd
        self.args = args
        if args.verbose:
            self.verbose = args.verbose
        else:
            self.verbose = False
            
    def remove_service(self, zeroconf, type, name):
        if self.verbose:
            print( f'Service {name} removed' )

    def add_service(self, zeroconf, type, name):
        info = zeroconf.get_service_info(type, name)
        self.ip = socket.inet_ntoa(info.addresses[0])
        self.port = info.port
        self.info = info
        if self.verbose:
            print( f'Found Service {info.name} added, running {self.cmd} on {self.ip}:{self.port}')
        getattr(self,self.cmd)()

    def get(self,path):
        self.session = Session()
        ip = self.ip
        port = self.port
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        url = f'https://{ip}:{port}/{path}'
        if self.verbose:
            print( f'starting GET {url}' )
        response = self.session.get( url, verify=False )
        return response
    
    def post(self,path,data):
        self.session = Session()
        ip = self.ip
        port = self.port
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        url = f'https://{ip}:{port}/{path}'
        if self.verbose:
            print( f'starting POST {url}' )
        response = self.session.get( url, verify=False, data = data )
        return response

    def push(self):
        response = self.post('push',self.content)
        print( response.content )
        self.exit()

    def pull(self):
        response = self.get('pull')
        # if binary use response.content
        print( response.text )
        self.exit()

    def last(self):
        response = self.get('last')
        # if binary use response.content
        print( response.text )
        self.exit()

    def exit(self):
        sys.stdout.flush()
        os._exit(0)
        
class Advertiser:
    def __init__(self,port=None):
        self.ip = self.get_ip()
        self.port = port if port else self.get_port() 
        
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

    def get_name(self):
        aa = pwd.getpwuid( os.getuid() )
        # could use pw_gecos
        return aa.pw_name
    
    def get_port(self):
        with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
            s.bind(('', 0))
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            return s.getsockname()[1]
    
    def start_advertisement(self,name):
        self.info = ServiceInfo(
            "_remotestash._tcp.local.",
            "{}._remotestash._tcp.local.".format(name),
            addresses=[socket.inet_aton(self.ip)],
            port=self.port,
            server=socket.gethostname() + '.local.',
            properties={"type": "remotestash_device"},
        )

        zeroconf = Zeroconf()
        zeroconf.register_service(self.info)

    def clean_advertisement(self):
        zeroconf = Zeroconf()
        zeroconf.unregister_service(self.info)
        zeroconf.close() 
    
class RequestHandler(BaseHTTPRequestHandler):
        
    def push(self):
        if self.body is None:
            pass

        stash = Stash({})
        stash.push( 'web', self.body )
        self.respond( 200, {'Content-type':'application/json; charset=utf-8'}, json.dumps( {'success':1} ).encode('utf-8') )

    def pull(self):
        stash = Stash({})
        data = stash.pull()
        self.respond( 200, {'Content-type':'text/plain; charset=utf-8'}, data )
        
    def last(self):
        stash = Stash({})
        data = stash.last()
        self.respond( 200, {'Content-type':'text/plain; charset=utf-8'}, data )

    def do_POST(self):
        self.do_GET()
        
    def do_GET(self):
        self.breakdown_request()
        if 'debug' in self.query_dict:
            self.request_debug_info()
            return

        response = None
        if self.parsed_path.path.startswith( '/push' ):
            self.push()
        elif self.parsed_path.path.startswith( '/pull' ):
            self.pull()
        elif self.parsed_path.path.startswith( '/last' ):
            self.last()
        else:
            self.respond( 500, {}, '' )
                
    def breakdown_request(self):
        self.parsed_path = parse.urlparse(self.path)
        self.query_dict = parse.parse_qs(self.parsed_path.query)
        
        if 'Content-Length' in self.headers:
            self.content_length = int( self.headers.get('Content-Length') )
            print( self.content_length )
            self.body = self.rfile.read(self.content_length)
            print( 'read' )
        else:
            self.body = None
            self.content_length = 0
            
    def request_debug_info(self):
        parsed_path = self.parsed_path
        message_parts = [
            'CLIENT VALUES:',
            'client_address={} ({})'.format(
                self.client_address,
                self.address_string()),
            'command={}'.format(self.command),
            'path={}'.format(self.path),
            'real path={}'.format(parsed_path.path),
            'query={}'.format(parsed_path.query),
            'query_dict={}'.format(self.query_dict),
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
        if self.body:
            message_parts.append( f'BODY [{self.content_length} bytes]' )
            message_parts.append( self.body.decode('utf-8') )
            
        message = '\n'.join(message_parts)
        self.respond( 200, { 'Content-Type' : 'text/plain; charset=utf-8' }, message )

    def respond(self,response_value, headers, content ):
        print( f'respond {response_value}  bytes' )
        self.send_response(response_value)
        if headers:
            for header,value in headers.items():
                self.send_header(header,value)
        self.end_headers()
        if content:
            self.wfile.write(content if isinstance(content,bytes) else content.encode( 'utf-8' ) )
            
        
class Driver :
    def __init__(self,args=None):
        self.args = args
        self.verbose = True;

    def cmd_listen(self,path = 'last'):
        zeroconf = Zeroconf()
        listener = Listener(path,self.args)
        if path == 'push':
            inputf = self.get_input_file()
            listener.content = inputf.read()
        else:
            listener.content = None
            
        browser = ServiceBrowser(zeroconf, "_remotestash._tcp.local.", listener)
        time.sleep(1.0)
        print( 'Failed to find a stash on the local network'  )

    def cmd_serve(self):
        zeroconf = Zeroconf()
        advertiser = Advertiser(int(self.args.port) if self.args.port else None)
        if self.args.name:
            name = self.args.name
        else:
            name = f'{advertiser.get_name()} remote stash'
        advertiser.start_advertisement(name)
        port = advertiser.port
        server = HTTPServer((advertiser.ip, port), RequestHandler)
        if os.path.isfile( os.path.expanduser( '~/.remotestash/homeweb.key' ) ):
            print( 'setup ssl' )
            server.socket = ssl.wrap_socket( server.socket,
                                             keyfile = os.path.expanduser( '~/.remotestash/homeweb.key' ),
                                             certfile = os.path.expanduser( '~/.remotestash/homeweb.crt' ),
                                             server_side = True )
        print(f'Starting server as {name} on {advertiser.ip}:{port}, use <Ctrl-C> to stop')
        try:
            while True:
                server.handle_request()
        finally:
            advertiser.clean_advertisement()

    def get_input_file(self):
        if 'file' in self.args and self.args.file:
            if os.path.isfile( self.args.file ):
                return open( self.args.file, 'r' )
            else:
                return None
        else:
            return sys.stdin
            
    def cmd_push(self):
        if self.args.local:
            inputf = self.get_input_file()
            content = inputf.read()
            stash = Stash(self.args)
            stash.push( 'nn', content )
        else:
            self.cmd_listen('push')
            

    def cmd_pull(self):
        if self.args.local:
            stash = Stash(self.args)
            data = stash.pull()
            print( data )
        else:
            self.cmd_listen('pull')
            
    def cmd_last(self):
        if self.args.local:
            stash = Stash(self.args)
            data = stash.last()
            print( data )
        else:
            self.cmd_listen('last')

            
if __name__ == "__main__":
    commands = {
        'listen':{'attr':'cmd_listen','help':'listen for server'},
        'serve':{'attr':'cmd_serve','help':'start server'},
        'push':{'attr':'cmd_push','help':'push content to stash'},
        'last':{'attr':'cmd_last','help':'push content to stash'},
        'pull':{'attr':'cmd_pull','help':'pull content to stash'},
        'list':{'attr':'cmd_list','help':'list stash'},
    }
    
    description = "\n".join( [ '  {}: {}'.format( k,v['help'] ) for (k,v) in commands.items() ] )
    
    parser = argparse.ArgumentParser( description='Remote Copy', formatter_class=argparse.RawTextHelpFormatter )
    parser.add_argument( 'command', metavar='Command', help='command to execute:\n' + description)
    parser.add_argument( '-l', '--local', action='store_true', help='use local stash' )
    parser.add_argument( '-n', '--name', help='name for service' )
    parser.add_argument( '-v', '--verbose', action='store_true', help='verbose output' )
    parser.add_argument( '-p', '--port', help='port to use if not set will use a free port' )
    parser.add_argument( 'file',    metavar='FILE', nargs='?' )
    args = parser.parse_args()

    command = Driver(args)

    if args.command in commands:
        getattr(command,commands[args.command]['attr'])()
    else:
        print( 'Invalid command "{}"'.format( args.command) )
        parser.print_help()
