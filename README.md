# RemoteStash

This implement a simple tool to enable sharing of picture or text between a phone and a computer with a shell. It is intended to substitute for AirDrop on a non apple computer, typically linux.

You can read the [background on the tool here](https://ro-z.net/blog/connectstats/how-to-airdrop-to-linux-part-1).

It is a simple tool, it is not intended to be fancy and it is open source so hopefully people can enhance it if needed or it may provide some help about how to put such a simple utility together.

It contains a python script to run on the shell and a companion iPhone app. 

# The python script

## Installation

the python script is self contains and can be run from anywhere. It requires python 3 and has a dependency on the zeroconf package which you'll need to install typically using `pip3 install zeroconf`.

The `remotestash` command can run in two mode: a client mode to push or pull information to a stash and a server mode that provide a service for clients to pull or push information to

## Server mode

You can run `remotestash serve` and this will start a server which will advertise itself on the network. By default it will name itself 'USERNAME RemoteStash', but you can use the option `-n myname` to specify the name to use. You could run the command as a service on your machine or manually from a terminal.

The server will behave like a stack, each item you push will move on top of the previous ones. You cam then `pull` them out, in that case each pull yields the next item until the stack is empty. Or you can ask for the `last` one, in which case each query for `last` returns the same item.

## Client mode

If you have a server running on a machine or the app open on your phone (which will then run a server as well), you can use `remotestash` as a client with the following commands:

* `remotestash push path/to/file` or `echo 'text' | remotestash push` to push the corresponding information to the server. 

* `remotestash pull` or `remotestash pull path/to/file` to pull the last information from the server.

In general, the `remotestash` client will connect to the first server it finds on the network, but if multiple exist you can specify the one your want with the `-n` option. The command `remotestash list` will try to discover all the servers available on the network.
You can use the option `-l` in which case, the client will use a local stack without using the network. Not sure how useful this is, but it was mostly for debugging as it's using the same logic the server uses to maintain its stash.

# The iPhone app

The iphone app can behave as a client to a remotestash server or as a server itself.

## Client mode

The app will present a text field or an image view depending on what is in the clipboard when it starts. The user interface is split into the *Local* and the *Remote* area. The local area represent what is in the phone and remote the server. You can use the `push` button to send the current content to the server. And `pull` or get the `last` item from the server onto your phone.

The current item on your phone can also be shared on your phone by clicking on the icon ![](https://raw.githubusercontent.com/roznet/remotestash/master/remotestash/Assets.xcassets/702-share.imageset/702-share%402x.png), which can be useful if you pull an image from the server for example to save it in your Photos app.

The app also provide a share extension, so if you have a safari page opened or a photo display the standard sharing menu from iOS will give you the option to use RemoteStash and share it to a running server on a computer or another phone.

## Server mode

When the app is opened it will start a server and advertise it on the network. So the `remotestash` command line tool will be able to pull item from the phone without the need for an existing server. Note that as soon as the app is closed or in the background the server will stop as well.


