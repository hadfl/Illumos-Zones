use 5.010001;

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Illumos::Zones',
    VERSION_FROM => 'lib/Illumos/Zones.pm',
    ABSTRACT     => 'A Perl Module to administrate Illumos Zones',
    AUTHOR       => 'Dominik Hassler <hadfl@cpan.org>',
    LICENSE      => 'gpl_3',
    META_MERGE   => {
        requires  => {perl => '5.010001'},
        resources => {
            license     => 'http://opensource.org/licenses/GPL-3.0',
            repository  => 'https://github.com/hadfl/Illumos-Zones',
            bugtracker  => 'https://github.com/Illumos-Zones/issues'
        },
        no_index => {directory => ['t', 'setup']}
    },
    test => {TESTS => 't/*.t'}
);

