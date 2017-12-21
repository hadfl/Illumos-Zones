package Illumos::Zones;

use strict;
use warnings;

# version
our $VERSION = '0.1.6';

# commands
my $ZONEADM  = '/usr/sbin/zoneadm';
my $ZONECFG  = '/usr/sbin/zonecfg';
my $ZONENAME = '/usr/bin/zonename';

my %ZMAP    = (
    zoneid    => 0,
    zonename  => 1,
    state     => 2,
    zonepath  => 3,
    uuid      => 4,
    brand     => 5,
    'ip-type' => 6,
);

# properties that can only be set on creation
my @CREATEPROP = qw(zonename zonepath brand ip-type);
my @LXNETPROPS = qw(gateway ips primary);

my $regexp = sub {
    my $rx = shift;
    my $msg = shift;

    return sub {
        my $value = shift;
        return $value =~ /$rx/ ? undef : "$msg ($value)";
    }
};

my $elemOf = sub {
    my $elems = [ @_ ];

    return sub {
        my $value = shift;
        return (grep { $_ eq $value } @$elems) ? undef
            : 'expected a value from the list: ' . join(', ', @$elems);
    }
};

my $getBrands  = sub {
    my @brands = ();
    for (glob('/usr/lib/brand/*/config.xml')) {
        open my $fh, "<$_" or next;
        while (<$fh>) {
            /<brand\s+name="(\S+)"/ or next;
            push @brands, $1;
            last;
        }
        close $fh;
    }
    return \@brands;
};

my $TEMPLATE = {
    zonename  => '',
    zonepath  => '',
    brand     => 'lipkg',
    'ip-type' => 'exclusive',
};

my $SCHEMA = {
    zonename    => {
        description => 'name of zone',
        validator   => $regexp->(qr/^[-\w]+$/, 'zonename not valid'),
    },
    zonepath    => {
        description => 'path to zone root',
        example     => '"zonepath" : "/zones/mykvm"',
        validator   => $regexp->(qr/^\/[-\w\/]+$/, 'zonepath is not a valid path'),
    },
    autoboot    => {
        optional    => 1,
        description => 'boot zone automatically',
        validator   => $elemOf->(qw(true false)),
    },
    bootargs    => {
        optional    => 1,
        description => 'boot arguments for zone',
        validator   => sub { return undef },
    },
    pool        => {
        optional    => 1,
        description => 'name of the resource pool this zone must be bound to',
        validator   => sub { return undef },
    },
    limitpriv   => {
        description => 'the maximum set of privileges any process in this zone can obtain',
        default     => 'default',
        validator   => $regexp->(qr/^[-\w,]+$/, 'limitpriv not valid'),
    },
    brand       => {
        description => "the zone's brand type",
        default     => 'lipkg',
        validator   => $elemOf->(@{$getBrands->()}),
    },
    'ip-type'   => {
        description => 'ip-type of zone. can either be "exclusive" or "shared"',
        default     => 'exclusive',
        validator   => $elemOf->(qw(exclusive shared)),
    },
    hostid      => {
        optional    => 1,
        description => 'emulated 32-bit host identifier',
        validator   => $regexp->(qr/^(?:[\da-f]{1,8}|)$/i, 'hostid not valid'),
    },
    'cpu-shares'    => {
        optional    => 1,
        description => 'the number of Fair Share Scheduler (FSS) shares',
        validator   => $regexp->(qr/^\d+$/, 'cpu-shares not valid'),
    },
    'max-lwps'    => {
        optional    => 1,
        description => 'the maximum number of LWPs simultaneously available',
        validator   => $regexp->(qr/^\d+$/, 'max-lwps not valid'),
    },
    'max-msg-ids'    => {
        optional    => 1,
        description => 'the maximum number of message queue IDs allowed',
        validator   => $regexp->(qr/^\d+$/, 'max-msg-ids not valid'),
    },
    'max-sem-ids'    => {
        optional    => 1,
        description => 'the maximum number of semaphore IDs allowed',
        validator   => $regexp->(qr/^\d+$/, 'max-sem-ids not valid'),
    },
    'max-shm-ids'    => {
        optional    => 1,
        description => 'the maximum number of shared memory IDs allowed',
        validator   => $regexp->(qr/^\d+$/, 'max-shm-ids not valid'),
    },
    'max-shm-memory'    => {
        optional    => 1,
        description => 'the maximum amount of shared memory allowed',
        validator   => $regexp->(qr/^\d+[KMGT]?$/i, 'max-shm-memory not valid'),
    },
    'scheduling-class'  => {
        optional    => 1,
        description => 'Specifies the scheduling class used for processes running',
        validator   => sub { return undef },
    },
    'fs-allowed'    => {
        optional    => 1,
        description => 'a comma-separated list of additional filesystems that may be mounted',
        validator   => $regexp->(qr/^(?:[-\w,]+|)$/, 'fs-allowed not valid'),
    },
    attr    => {
        optional    => 1,
        array       => 1,
        description => 'generic attributes',
        members     => {
            name    => {
                description => 'attribute name',
                validator   => sub { return undef },
            },
            type    => {
                description => 'attribute type',
                validator   => sub { return undef },
            },
            value   => {
                description => 'attribute value',
                validator   => sub { return undef },
            },
        },
    },
    'capped-cpu'    => {
        optional    => 1,
        description => 'limits for CPU usage',
        members     => {
            ncpus       => {
                description => 'sets the limit on the amount of CPU time. value is the percentage of a single CPU',
                validator   => $regexp->(qr/^(?:\d*\.\d+|\d+\.\d*)$/, 'ncpus value not valid. check man zonecfg'),
            },
        },
    },
    'capped-memory' => {
        optional    => 1,
        description => 'limits for physical, swap, and locked memory',
        members     => {
            physical    => {
                optional    => 1,
                description => 'limits of physical memory. can be suffixed by (K, M, G, T)',
                validator   => $regexp->(qr/^\d+[KMGT]?$/i, 'physical capped-memory is not valid. check man zonecfg'),
            },
            swap    => {
                optional    => 1,
                description => 'limits of swap memory. can be suffixed by (K, M, G, T)',
                validator   => $regexp->(qr/^\d+[KMGT]?$/i, 'swap capped-memory is not valid. check man zonecfg'),
            },
            locked    => {
                optional    => 1,
                description => 'limits of locked memory. can be suffixed by (K, M, G, T)',
                validator   => $regexp->(qr/^\d+[KMGT]?$/i, 'locked capped-memory is not valid. check man zonecfg'),
            },
        },
    },
    dataset => {
        optional    => 1,
        array       => 1,
        description => 'ZFS dataset',
        members => {
            name    => {
                description => 'the name of a ZFS dataset to be accessed from within the zone',
                validator   => $regexp->(qr/^\w[-\w\/]+$/, 'dataset name not valid. check man zfs'),
            },
        },
    },
    'dedicated-cpu' => {
        optional    => 1,
        description => "subset of the system's processors dedicated to this zone while it is running",
        members     => {
            ncpus   => {
                description => "the number of cpus that should be assigned for this zone's exclusive use", 
                validator   => $regexp->(qr/^\d+(?:-\d+)?$/, 'dedicated-cpu ncpus not valid. check man zonecfg'),
            },
            importance  => {
                optional    => 1,
                description => 'specifies the pset.importance value for use by poold',
                validator   => sub { return undef },
            },
        },
    },
    device  => {
        optional    => 1,
        array       => 1,
        description => 'device',
        members     => {
            match   => {
                description => 'device name to match',
                validator   => sub { return undef },
            },
        },
    },
    fs  => {
        optional    => 1,
        array       => 1,
        description => 'file-system',
        members     => {
            dir     => {
                description => 'directory of the mounted filesystem',
                validator   => $regexp->(qr/^\/[-\w\/\.]+$/, 'dir is not a valid directory'),
            },
            special => {
                description => 'path of fs to be mounted',
                validator   => $regexp->(qr/^[-\w\/\.]+$/, 'special is not valid'),
            },
            raw     => {
                optional    => 1,
                description => 'path of raw disk',
                validator   => $regexp->(qr/^\/[-\w\/]+$/, 'raw is not valid'),
            },
            type    => {
                description => 'type of fs',
                validator   => $elemOf->(qw(lofs zfs)),
            },
            options => {
                optional    => 1,
                description => 'mounting options',
                validator   => $regexp->(qr/^\[[\w,]*\]$/, 'options not valid'),
            },
        },
    },
    net => {
        optional    => 1,
        array       => 1,
        description => 'network interface',
        members     => {
            address     => {
                optional    => 1,
                description => 'IP address of network interface',
                validator   => $regexp->(qr/^\d{1,3}(?:\.\d{1,3}){3}(?:\/\d{1,2})?$/, 'IP address not valid'),
            },
            physical    => {
                description => 'network interface',
                validator   => $regexp->(qr/^[-\w]+/, 'physical not valid'),
            },
            defrouter   => {
                optional    => 1,
                description => 'IP address of default router',
                validator   => $regexp->(qr/^\d{1,3}(?:\.\d{1,3}){3}$/, 'IP address not valid'),
            },
            ips         => {
                optional    => 1,
                array       => 1,
                description => 'IPs for LX zones',
                validator   => $regexp->(qr/^\d{1,3}(?:\.\d{1,3}){3}(?:\/\d{1,2})$/, 'Not a valid CIDR IP address'),
            },
            gateway     => {
                optional    => 1,
                description => 'Gateway for LX zones',
                validator   => $regexp->(qr/^\d{1,3}(?:\.\d{1,3}){3}$/, 'IP address not valid'),
            },
            primary     => {
                optional    => 1,
                description => 'Primary Interface for LX zones',
                validator   => $elemOf->(qw(true false)),
            },
        },
    },
    rctl    => {
        optional    => 1,
        array       => 1,
        description => 'resource control',
        members => {
            name    => {
                description => 'resource name',
                validator   => sub { return undef },
            },
            value   => {
                description => 'resource value',
                validator   => sub { return undef },
            },
        },
    },
};

# private methods
my $RESOURCES = sub {
    return [ map { $SCHEMA->{$_}->{members} ? $_ : () } keys %$SCHEMA ];
};

my $resIsArray = sub {
    my $self = shift;
    my $res  = shift;

    return $SCHEMA->{$res}->{array};
};

my $RESARRAYS = sub {
    return [ map { $SCHEMA->{$_}->{array} ? $_ : () } @{$RESOURCES->()} ];
};

my $zoneCmd = sub {
    my $self     = shift;
    my $zoneName = shift;
    my $cmd      = shift;
    my @opts     = @_;

    my @cmd = ($ZONEADM, '-z', $zoneName, $cmd, @opts);

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    system(@cmd) and die "ERROR: cannot $cmd zone $zoneName\n";
};

my $encodeLXnetProp = sub {
    my $self     = shift;
    my $prop     = shift;
    my $value    = shift;

    $value = ref $value eq 'ARRAY' ? "(name=$prop,value=\"" . join (',', @$value) . '")'
        : "(name=$prop,value=\"$value\")";
    $prop  = 'property';

    return ($prop, $value);
};

my $decodeLXnetProp = sub {
    my $self     = shift;
    my $prop     = shift;
    my $value    = shift;

    return ($prop, $value) if !($prop eq 'property');

    ($prop)      = $value =~ /name=(\w+)/;
    my @values = split /,/, ($value =~ /value="([^"]+)"/)[0];
    if (!$SCHEMA->{net}->{members}->{$prop}->{array}) {
        return ($prop, $values[0]);
    }
    return ($prop, [ @values ]);
};

# constructor
sub new {
    my $class = shift;
    my $self = { @_ };
    return bless $self, $class
}

# public methods
sub schema {
    return $SCHEMA;
}

sub template {
    return $TEMPLATE;
}

sub resources {
    return $RESOURCES->();
}

sub resourceArrays {
    return $RESARRAYS->();
}

# zoneName is a static method
sub zoneName {
    my @cmd = ($ZONENAME);

    open my $zones, '-|', @cmd
        or die "ERROR: cannot get zonename\n";

    chomp (my $zonename = <$zones>);

    return $zonename;
}

# isGZ is a static method
sub isGZ {
    return zoneName() eq 'global';
}

sub listZones {
    my $self = shift;
    my $opts = shift;

    my @cmd = ($ZONEADM, qw(list -cp));

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    open my $zones, '-|', @cmd
        or die "ERROR: cannot get list of Zones\n";

    my $zoneList = [];
    while (my $zone = <$zones>) {
        chomp $zone;
        my $zoneCfg = { map { $_ => (split /:/, $zone)[$ZMAP{$_}] } keys %ZMAP };
        # apply brand and SMF filter
        next if $opts->{brandFilter} && $zoneCfg->{brand} !~ /$opts->{brandFilter}/;
        next if $opts->{requireSMF}  && $zoneCfg->{zonename} ne 'global'
            && !-f $zoneCfg->{zonepath} . '/root/etc/svc/repository.db';

        push @$zoneList, $zoneCfg;
    }

    return $zoneList;
}

sub listZone {
    my $self     = shift;
    my $zoneName = shift;
    my $opts     = shift;

    my ($zone) = grep { $_->{zonename} eq $zoneName } @{$self->listZones($opts)};

    return $zone;
}

sub zoneState {
    my $self     = shift;
    my $zoneName = shift;
    my $opts     = shift;

    my $zone = $self->listZone($zoneName, $opts);

    return $zone ? $zone->{state} : undef;
}

sub boot {
    my $self = shift;

    $self->$zoneCmd(shift, 'boot');
}

sub shutdown {
    my $self     = shift;
    my $zoneName = shift;
    my @reboot   = $_[0] ? qw(-r) : ();

    $self->$zoneCmd($zoneName, 'shutdown', @reboot);
}

sub reboot {
    my $self = shift;

    $self->shutdown(shift, 1);
};

sub createZone {
    my $self     = shift;
    my $zoneName = shift;
    my $props    = shift;

    my @cmd = ($ZONECFG, '-z', $zoneName, qw(create -b ;));

    for my $prop (keys %$props) {
        push @cmd, ('set', $prop, '=', $props->{$prop}, ';');
    }

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    system(@cmd) and die "ERROR: cannot create zone $zoneName\n";
}

sub deleteZone {
    my $self     = shift;
    my $zoneName = shift;

    my @cmd = ($ZONECFG, '-z', $zoneName, 'delete');

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    system(@cmd) and die "ERROR: cannot delete zone $zoneName\n";
}

sub installZone {
    my $self     = shift;
    my $zoneName = shift;
    my $img      = shift;

    $self->$zoneCmd($zoneName, 'install', ($img ? ('-s', $img) : ()));
}

sub uninstallZone {
    my $self = shift;

    $self->$zoneCmd(shift, 'uninstall');
}

sub zoneExists {
    my $self     = shift;
    my $zoneName = shift;
    my $opts     = shift;

    return $self->listZone($zoneName, $opts) ? 1 : 0;
}

sub getZoneProperties {
    my $self     = shift;
    my $zoneName = shift;
    my $properties = {};

    return {} if !$self->zoneExists($zoneName);

    my @cmd = ($ZONECFG, '-z', $zoneName, 'info');

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    open my $props, '-|', @cmd
        or die "ERROR: cannot get properties of zone '$zoneName'\n";

    my $resName;
    while (<$props>) {
        chomp;
        # remove square brackets at beginning and end of line
        s/^(\s*)\[/$1/ && s/\]\s*//;
        my ($isres, $property, $value) = /^(\s+)?([^:]+):(?:\s+(.*))?$/;
        # at least property must be valid
        $property or next;

        if (defined $isres && length $isres > 0) {
            # transform net properties for LX zones
            ($property, $value) = $self->$decodeLXnetProp($property, $value) if $resName eq 'net';

            # check if property exists in schema
            grep { $_ eq $property } keys %{$SCHEMA->{$resName}->{members}} or next; 
            if ($self->$resIsArray($resName)) {
                $properties->{$resName}->[-1]->{$property} = $value;
            }
            else {
                $properties->{$resName}->{$property} = $value;
            }
        }
        else {
            # check if property exists in schema
            grep { $_ eq $property } keys %$SCHEMA or next;
            # check if property is a resource
            grep { $_ eq $property } @{$RESOURCES->()} and do {
                $resName = $property;
                if ($self->$resIsArray($property)) {
                    push @{$properties->{$property}}, {};
                }
                next;
            };
            $properties->{$property} = $value;
        }
    }
    
    return $properties;
}

sub setZoneProperties {
    my $self     = shift;
    my $zoneName = shift;
    my $props    = shift;
    my $img      = shift;
    my $oldProps = $self->getZoneProperties($zoneName);

    $self->zoneExists($zoneName) || $self->createZone($zoneName,
        { map { $_ => $props->{$_} } @CREATEPROP });

    # remove props that cannot be changed after creation
    delete $props->{$_} for @CREATEPROP;

    my $state = $self->zoneState($zoneName);
    $self->installZone($zoneName, $img) if $state eq 'configured';

    # clean up all resources
    $self->clearResources($zoneName);

    for my $prop (keys %$props) {
        if (ref $props->{$prop} eq 'ARRAY') {
            for my $elem (@{$props->{$prop}}) {
                $self->addResource($zoneName, $prop, $elem);
            }
        }
        elsif (grep { $_ eq $prop } @{$RESOURCES->()}) {
            $self->addResource($zoneName, $prop, $props->{$prop});
        }
        else {
            next if $oldProps->{$prop} && $oldProps->{$prop} eq $props->{$prop};
            if ($props->{$prop}) {
                $self->setProperty($zoneName, $prop, $props->{$prop});
            }
            else {
                $self->clearProperty($zoneName, $prop);
            }
        }
    }
}

sub resourceExists {
    my $self     = shift;
    my $zoneName = shift;
    my $resource = shift;
    my $property = shift;
    my $value    = shift;

    my @cmd = ($ZONECFG, '-z', $zoneName, 'info', $resource);

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    open my $res, '-|', @cmd
        or die "ERROR: cannot get resource '$resource' of zone '$zoneName'\n";

    chomp (my @resources = <$res>);

    return $property && $value ? grep { /\s+$property:\s+$value/ } @resources : @resources;
}

sub addResource {
    my $self     = shift;
    my $zoneName = shift;
    my $resource = shift;
    my $props    = shift;

    my @cmd = ($ZONECFG, '-z', $zoneName, 'add', "$resource;");

    for my $property (keys %$props) {
        # check if it is an LX net property
        if (grep { $_ eq $property } @LXNETPROPS) {
            my ($prop, $value) = $self->$encodeLXnetProp($property, $props->{$property});
            push @cmd, ('add', $prop, $value, ';');
        }
        else {
            push @cmd, ('set', "$property=$props->{$property};");
        }
    }
    push @cmd, qw(end);

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    system(@cmd) and die "ERROR: cannot set properties for resource '$resource' of $zoneName\n";
}

sub delResource {
    my $self     = shift;
    my $zoneName = shift;
    my $resource = shift;
    my $property = shift;
    my $value    = shift;

    return if !$self->resourceExists($zoneName, $resource, $property, $value);

    my @cmd = ($ZONECFG, '-z', $zoneName, 'remove');
    if ($property && $value) {
        push @cmd, ($resource, $property, '=', $value);
    }
    else {
        push @cmd, ('-F', $resource);
    }
    
    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    system(@cmd) and die "ERROR: cannot remove resource '$resource' of $zoneName\n";
}

sub clearResources {
    my $self     = shift;
    my $zoneName = shift;

    for my $res (@{$RESOURCES->()}) {
        $self->delResource($zoneName, $res);
    }
}

sub setProperty {
    my $self     = shift;
    my $zoneName = shift;
    my $property = shift;
    my $value    = shift;

    my @cmd = ($ZONECFG, '-z', $zoneName, 'set', $property, '=', "\"$value\"");

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    system(@cmd) and die "ERROR: cannot set property $property of $zoneName\n";
}

sub clearProperty {
    my $self     = shift;
    my $zoneName = shift;
    my $property = shift;

    my @cmd = ($ZONECFG, '-z', $zoneName, 'clear', $property);

    print STDERR '# ' . join(' ', @cmd) . "\n" if $self->{debug};
    system(@cmd) and die "ERROR: cannot remove property $property of $zoneName\n";
}

1;

__END__

=head1 NAME

Illumos::Zones - Zone administration class

=head1 SYNOPSIS

 use Illumos::Zones;
 ...
 my $zone = Illumos::Zones->new(debug => 0);
 ...

=head1 DESCRIPTION

class to manage Zones

=head1 ATTRIBUTES

=head2 debug

print debug information to STDERR

=head1 METHODS

=head2 schema

returns a schema for "Data::Processor" so that the zone config can be
validated before written to the zone.

 my $schema = $zone->schema();

=head2 template

returns a minimal template config for creating a zone

 my $cfg = $zone->template();

=head2 resources

returns a list of zone resources

 my @res = @{$zone->resources()};

=head2 resourceArrays

returns a list of zone resources which are arrays (i.e. can have multiple entries)

 my @resArray = @{$zone->resourceArrays()};

=head2 zoneName

static method. returns the name of the current zone

 Illumos::Zones->zonename();

=head2 isGZ

static method. returns true if we are on the global zone

 Illumos::Zones->isGZ();

=head2 listZones

returns the list of zones. each element contains a hash with all the zone infos
(cf. 'zoneamd list')

 my @zones = @{$zone->listZones()};

=head2 listZone

returns a hash with all the zone infos (cf. 'zoneadm list')

 my %zone = %{$zone->listZone($zonename)};

=head2 zoneState

returns the state of the zone

 $zone->zoneState($zonename);

=head2 boot

boots the zone
 
 $zone->boot($zonename);

=head2 shutdown

gracefully shuts down the zone

 $zone->shutdown($zonename);

=head2 reboot

reboots the zone

 $zone->reboot($zonename);

=head2 createZone

creates a zone and applies the properties

 $zone->createZone($zonename, { %props });

=head2 deleteZone

deletes a zone (zone must be uninstalled first)

 $zone->deleteZone($zonename);

=head2 installZone

installs a zone

 $zone->install($zonename);

=head2 uninstallZone

uninstalls a zone

 $zone->uninstall($zonename);

=head2 zoneExists

checks whether a zone exists or not

 $zone->zoneExists($zonename);

=head2 getZoneProperties

returns a JSON data structure which contains all the zone properties

 my %zonecfg = %{$zone->getZoneProperties($zonename)};

=head2 setZoneProperties

applies the properties provided in a JSON data structure to the zone
if the zone does not exist it will be created

 $zone->setZoneProperties($zonename, { %zonecfg });

=head2 resourceExists

checks whether a resource exists or not. C<$property> and C<$value> are
optional parameters

 $zone->resourceExists($zonename, $resource, $property, $value);

=head2 addResource

adds a resource

 $zone->addResource($zonename, $resource, { %props });

=head2 delResource

deletes a resource. C<$property> and C<$value> are optional parameters
for distinction if multiple resources of the same type exists.

 $zone->delResource($zonename, $resource, $property, $value);

=head2 clearResources

deletes all resrouces

 $zone->clearResources($zonename);

=head2 setProperty

sets a property

 $zone->setProperty($zonename, $property, $value);

=head2 clearProperty

sets a property to the default value

 $zone->clearProperty($zonename, $property);

=head1 COPYRIGHT

Copyright (c) 2015 by OETIKER+PARTNER AG. All rights reserved.

=head1 LICENSE

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>.

=head1 AUTHOR

S<Dominik Hassler E<lt>hadfl@cpan.orgE<gt>>,
S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

2015-05-08 had Initial Version

=cut
