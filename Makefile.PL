use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'DISTNAME'	=> 'WebFetch',
    'VERSION_FROM' => 'WebFetch.pm', # finds $VERSION
    'NAME' => 'WebFetch',
    'DIR' => [ "sub" ],
    'PREREQ_PM' => {
    	'LWP::UserAgent' => 0,
    	'HTTP::Request' => 0,
	'Locale::Country' => 0
	},
);
