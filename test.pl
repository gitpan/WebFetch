# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

BEGIN {
	# enumerate modules for loading tests
	@modules = ( "WebFetch::CNETnews", "WebFetch::CNNsearch",
		"WebFetch::COLA", "WebFetch::DebianNews",
		"WebFetch::Freshmeat", "WebFetch::General",
		"WebFetch::LinuxDevNet", "WebFetch::LinuxTelephony",
		"WebFetch::LinuxToday", "WebFetch::ListSubs",
		"WebFetch::SiteNews", "WebFetch::Slashdot",
		"WebFetch::32BitsOnline", "WebFetch::YahooBiz" );

	$| = 1; print "1..".($#modules+2)."\n"; }
END {print "not ok 1\n" unless $loaded;}
use WebFetch;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# perform module loading tests
for ( $i=0; $i <= $#modules; $i++ ) {
	if (( eval "require ".$modules[$i] ) and ! $@ ) {
		print "ok ".($i+2)."\n";
	} else {
		print STDERR "test failed: $@\n";
		print "not ok ".($i+2)."\n";
	}
}
