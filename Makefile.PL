use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Hadashot',
  VERSION_FROM => 'lib/Hadashot.pm',
  AUTHOR       => 'Dotan Dimet <dotan@corky.net>',
  PREREQ_PM    => {
    'Mojolicious'                     => '4.20',
    'Mojolicious::Plugin::FeedReader' => '0.02',
    'Mango'                           => '0.04',
    'HTTP::Date'                      => '6.02',
    'Time::Zone'                      => '2.2'
  },
    LICENSE      => 'artistic_2',
    ABSTRACT     => 'RSS Reader, using Mongo DB and Mojolicious',
    META_MERGE   => {
    requires  => {perl => '5.010001'},
    resources => {
      license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
      repository  => 'http://github.com/dotandimet/hadashot',
      bugtracker  => 'http://github.com/dotandimet/hadashot/issues'
    },
    no_index => {directory => ['t']}
  },
  test => {TESTS => 't/*.t'}
);
