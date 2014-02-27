use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Hadashot',
  VERSION_FROM => 'lib/Hadashot.pm',
  AUTHOR       => 'Dotan Dimet <dotan@corky.net>',
  PREREQ_PM    => {
    'Mojolicious'                     => '4.20',
    'Mojolicious::Plugin::FeedReader' => '0.01',
    'Mango'                           => '0.04',
    'HTTP::Date'                      => '6.02',
    'Time::Zone'                      => '2.2'
  },
  test => {TESTS => 't/*.t'}
);
