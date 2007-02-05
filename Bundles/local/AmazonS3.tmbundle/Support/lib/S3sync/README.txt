Welcome to s3sync.rb         
--------------------
This is a ruby program that easily transfers directories between a local
directory and an S3 bucket:prefix. It behaves somewhat, but not precisely, like
the rsync program. In particular, it shares rsync's peculiar behavior that
trailing slashes on the source side are meaningful. See examples below.

One benefit over some other comparable tools is that s3sync goes out of its way
to mirror the directory structure on S3.  Meaning you don't *need* to use s3sync
later in order to view your files on S3.  You can just as easily use an S3
shell, a web browser (if you used the --public-read option), etc.  Note that
s3sync is NOT necessarily going to be able to read files you uploaded via some
other tool.  This includes things uploaded with the old perl version!  For best
results, start fresh!

s3sync runs happily on linux, probably other *ix, and also Windows (except that
symlinks and permissions management features don't do anything on Windows). If
you get it running somewhere interesting let me know (see below)

s3sync is free, and license terms are included in all the source files. If you
decide to make it better, or find bugs, please let me know via the S3 forums or
gbs-s3@10forward.com

The original inspiration for this tool is the perl script by the same name which
was made by Thorsten von Eicken (and later updated by me). This ruby program
does not share any components or logic from that utility; the only relation is
that it performs a similar task.


Examples: 
---------
(using S3 bucket 'bucket' and prefix 'pre')
  Put the local etc directory itself into S3
        s3sync.rb  -r  /etc  bucket:pre
        (This will yield S3 keys named  pre/etc/...)
  Put the contents of the local /etc dir into S3, rename dir:
        s3sync.rb  -r  /etc/  bucket:pre/etcbackup
        (This will yield S3 keys named  pre/etcbackup/...)
  Put contents of S3 "directory" etc into local dir
        s3sync.rb  -r  bucket:pre/etc/  /root/etcrestore
        (This will yield local files at  /root/etcrestore/...)
  Put the contents of S3 "directory" etc into a local dir named etc
        s3sync.rb  -r  bucket:pre/etc  /root
        (This will yield local files at  /root/etc/...)


Prerequisites:
--------------
You need a functioning Ruby (>=1.8.4) installation, as well as the OpenSSL ruby 
library (which may or may not come with your ruby).

How you get these items working on your system is really not any of my 
business, but you might find the following things helpful.  If you're using 
Windows, the ruby site has a useful "one click installer" (although it takes 
more clicks than that, really).  On debian (and ubuntu, and other debian-like 
things), there are apt packages available for ruby and the open ssl lib.


Your environment:
-----------------
s3sync needs to know several interesting values to work right.  It looks for 
them in the following environment variables.

Required:
	AWS_ACCESS_KEY_ID
	AWS_SECRET_ACCESS_KEY
	
	If you don't know what these are, then s3sync is probably not the
	right tool for you to be starting out with.
Optional:
	AWS_S3_HOST - I don't see why the default would ever be wrong
	SSL_CERT_DIR - Where your Cert Authority keys live; for verification
	S3SYNC_RETRIES - How many HTTP errors to tolerate before exiting
	S3SYNC_WAITONERROR - How many seconds to wait after an http error
	S3SYNC_MIME_TYPES_FILE - Where is your mime.types file
	S3SYNC_NATIVE_CHARSET - For example Windows-1252.  Defaults to ISO-8859-1.

If you really want to hardcode these instead of putting them in the 
environment, you can do so by editing the top of the s3sync.rb file.  However 
if you do this, you WILL overwrite them later by accident when updating to a 
new version.  You have been warned.

By the way, I use "envdir" from the daemontools package to set up my env 
variables easily: http://cr.yp.to/daemontools/envdir.html
For example:
	envdir /root/s3sync/env /root/s3sync/s3sync.rb -etc etc etc
I know there are other similar tools out there as well.  

You can also just call it in a shell script where you have exported the vars 
first such as:
#!/bin/bash
export AWS_ACCESS_KEY_ID=valueGoesHere
...
s3sync.rb -etc etc etc


A word on SSL_CERT_DIR:
-----------------------
On my debian install I didn't find any root authority public keys.  I installed
some by running this shell archive: 
http://mirbsd.mirsolutions.de/cvs.cgi/src/etc/ssl.certs.shar
(You have to click download, and then run it wherever you want the certs to be
placed).  I do not in any way assert that these certificates are good,
comprehensive, moral, noble, or otherwise correct.  But I am using them.

If you don't set up a cert dir, and try to use ssl, then you'll 1) get an ugly
warning message slapped down by ruby, and 2) not have any protection AT ALL from
malicious servers posing as s3.amazonaws.com.  Seriously... you want to get
this right if you're going to have any sensitive data being tossed around.

ALTERNATELY: Here is a simpler approach offered to me thanks to Paul Hoffman.
Assuming you have a directory to put your root certs, just create one file in
there, containing:

-----BEGIN CERTIFICATE-----
MIICNDCCAaECEAKtZn5ORf5eV288mBle3cAwDQYJKoZIhvcNAQECBQAwXzELMAkG
A1UEBhMCVVMxIDAeBgNVBAoTF1JTQSBEYXRhIFNlY3VyaXR5LCBJbmMuMS4wLAYD
VQQLEyVTZWN1cmUgU2VydmVyIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTk0
MTEwOTAwMDAwMFoXDTEwMDEwNzIzNTk1OVowXzELMAkGA1UEBhMCVVMxIDAeBgNV
BAoTF1JTQSBEYXRhIFNlY3VyaXR5LCBJbmMuMS4wLAYDVQQLEyVTZWN1cmUgU2Vy
dmVyIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MIGbMA0GCSqGSIb3DQEBAQUAA4GJ
ADCBhQJ+AJLOesGugz5aqomDV6wlAXYMra6OLDfO6zV4ZFQD5YRAUcm/jwjiioII
0haGN1XpsSECrXZogZoFokvJSyVmIlZsiAeP94FZbYQHZXATcXY+m3dM41CJVphI
uR2nKRoTLkoRWZweFdVJVCxzOmmCsZc5nG1wZ0jl3S3WyB57AgMBAAEwDQYJKoZI
hvcNAQECBQADfgBl3X7hsuyw4jrg7HFGmhkRuNPHoLQDQCYCPgmc4RKz0Vr2N6W3
YQO2WxZpO8ZECAyIUwxrl0nHPjXcbLm7qt9cuzovk2C2qUtN8iD3zV9/ZHuO3ABc
1/p3yjkWWW8O6tO1g39NTUJWdrTJXwT4OPjr0l91X817/OWOgHz8UA==
-----END CERTIFICATE-----

and that should be enough. The other ones in the archive are (apparently) not
used for the S3 chain. I want to note that at the moment this doesn't seem to
work for me, but I may just be boning up something simple.


Getting started:
----------------
Invoke by typing s3sync.rb and you should get a nice usage screen.
Options can be specified in short or long form (except --delete, which has no 
short form)

ALWAYS TEST NEW COMMANDS using --dryrun(-n) if you want to see what will be
affected before actually doing it. ESPECIALLY if you use --delete. Otherwise, do
not be surprised if you misplace a '/' or two and end up deleting all your
precious, precious files.

If you use the --public-read(-p) option, items sent to S3 will be ACL'd so that
anonymous web users can download them, given the correct URL. This could be
useful if you intend to publish directories of information for others to see.
For example, I use s3sync to publish itself to its home on S3 via the following
command: s3sync.rb -v -p publish/ ServEdge_pub:s3sync Where the files live in a
local folder called "publish" and I wish them to be copied to the URL:
http://s3.amazonaws.com/ServEdge_pub/s3sync/... If you use --ssl(-s) then your
connections with S3 will be encrypted. Otherwise your data will be sent in clear
form, i.e. easy to intercept by malicious parties.

If you want to prune items from the destination side which are not found on the
source side, you can use --delete. Always test this with -n first to make sure
the command line you specify is not going to do something terrible to your
cherished and irreplaceable data.


Updates and other discussion: 
----------------------------- 
The latest version of s3sync should normally be at:
	http://s3.amazonaws.com/ServEdge_pub/s3sync/s3sync.tar.gz 
and the Amazon S3 forums probably have a few threads going on it at any given
time. I may not always see things posted to the threads, so if you want you can
contact me at gbs-s3@10forward.com too.


Change Log:
-----------

2006-09-29:
Added support for --expires and --cache-control. Eg:
--expires="Thu, 01 Dec 2007 16:00:00 GMT"
--cache-control="no-cache"

Thanks to Charles for pointing out the need for this, and supplying a patch
proving that it would be trivial to add =) Apologies for not including the short
form (-e) for the expires. I have a rule that options taking arguments should
use the long form.
----------

2006-10-04
Several minor debugs and edge cases.
Fixed a bug where retries didn't rewind the stream to start over.
----------

2006-10-12
Version 1.0.5
Finally figured out and fixed bug of trying to follow local symlink-to-directory.
Fixed a really nasty sorting discrepancy that caused problems when files started
with the same name as a directory.
Retry on connection-reset on the S3 side.
Skip files that we can't read instead of dying.
----------

2006-10-12
Version 1.0.6
Some GC voodoo to try and keep a handle on the memory footprint a little better.
There is still room for improvement here.
----------

2006-10-13
Version 1.0.7
Fixed symlink dirs being stored to S3 as real dirs (and failing with 400)
Added a retry catch for connection timeout error.
(Hopefully) caught a bug that expected every S3 listing to contain results
----------

2006-10-14
Version 1.0.8
Was testing for file? before symlink? in localnode.stream. This meant that for
symlink files it was trying to shove the real file contents into the symlink
body on s3.
----------

2006-10-14
Version 1.0.9
Woops, I was using "max-entries" for some reason but the proper header is
"max-keys".  Not a big deal.
Broke out the S3try stuff into a separate file so I could re-use it for s3cmd.rb
----------

2006-10-16
Added a couple debug lines; not even enough to call it a version revision.
----------

2006-10-25
Version 1.0.10
UTF-8 fixes.
Catching a couple more retry-able errors in s3try (instead of aborting the
program).
----------

2006-10-26
Version 1.0.11
Revamped some details of the generators and comparator so that directories are
handled in a more exact and uniform fashion across local and S3. 
----------

2006-11-28
Version 1.0.12
Added a couple more error catches to s3try.
----------

2007-01-08
Version 1.0.13
Numerous small changes to slash and path handling, in order to catch several 
cases where "root" directory nodes were not being created on S3.
This makes restores work a lot more intuitively in many cases.

2007-01-25
Version 1.0.14
Peter Fales' marker fix.
Also, markers should be decoded into native charset (because that's what s3
expects to see).

FNORD