== Textile Bundle port for E Text Editor
This is a port of the Textmate Textile Bundle as maintained by Antonio Cangiano:
http://fisheye2.cenqua.com/browse/textmate-bundles/trunk/Bundles/Textile.tmbundle

== Maintainer(s)
Charles Roper
reachme [at] charlesroper [dot] co [dot] uk

== Notes
Only two changes have so far been needed:

* The new Insert Color command has been replace with a wxCocoaDialog powered version. This is because the Textmate version requires the as yet incompatible ui.rb support library.

* The Show Documentation command now opens in the default browser