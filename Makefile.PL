use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME      => 'Hadashot',
  VERSION_FROM   => 'lib/Hadashot.pm',
  PREREQ_PM => {'Mojolicious' => '4.20',
		'Mango'       => '0.04',
    'HTTP::Date' => '6.02',
		'Time::Zone' => '2.2'
     },
  test      => {TESTS => 't/*.t'}
);
