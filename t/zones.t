#!/usr/bin/env perl

use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';

unshift @INC, sub {
    my(undef, $filename) = @_;
    return () if $filename !~ /Zones/;
    if ( my $found = (grep { -e $_ } map { "$_/$filename" } grep { !ref } @INC)[0] ) {
                local $/ = undef;
                open(my $fh, '<', $found) || die("Can't read module file $found\n");
                my $module_text = <$fh>;
                close($fh);

                # define everything in a sub, so Devel::Cover will DTRT
                # NB this introduces no extra linefeeds so D::C's line numbers
                # in reports match the file on disk
                $module_text =~ s/(.*?package\s+\S+)(.*)__END__/$1sub main {$2} main();/s;
                
                # filehandle on the scalar
                open ($fh, '<', \$module_text);

                # and put it into %INC too so that it looks like we loaded the code
                # from the file directly
                $INC{$filename} = $found;
                return $fh;
     } else {
          return ();
    }
};

use Test::More tests => 2;

use_ok 'Illumos::Zones';

my $t = Illumos::Zones->new();

is (ref $t,'Illumos::Zones', 'Instantiation');

exit 0;

1;

