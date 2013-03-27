use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {'Mojolicious' => '3.91',
		'Mango'       => '0.04' },
  test      => {TESTS => 't/*.t'}
);
