#!/usr/bin/perl

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use self;
use remote;
use adc::common;
use digraph;
use Data::Dumper;

$ENV{LANG}='C';
$ENV{LC_ALL}='C';

=encoding utf-8

=head1 NAME

B<vilan> -- LAN topology visualizer

=head1 SYNOPSIS

   vilan [ -c config.pm ]

Here will be some examples of syntax and all parameters

=head1 DESCRIPTION

The B<vilan> utility scans network and makes it's topology in digraph format.

=cut 

our %HOSTS;
#TODO parse arguments [ -c config.pl ]
my $config_file = './config.pl';
unless (my $rc = do $config_file) {
   warn "couldn't parse $config_file: $@" if $@;
   warn "couldn't do $config_file: $!" unless defined $rc;
   warn "couldn't run $config_file" unless $rc;
}

#my $self = self->new();

#while (my ($own_ip, $own_mask) = each $self->{own_ips}) {
#   digraph->add_connection($own_ip, 
#      common->find_ips_in_subnet($own_ip, $own_mask, $self->{reachable_ips})
#   );
#}

#digraph->add_gateway($_) for @{$self->{gws}};

#digraph->print();


# output is bugged!
#while (my ($own_ip, $own_mask) = each $self->{own_ips}) {
#   digraph->add_connection($own_ip, 
#      common->find_ips_in_subnet($own_ip, $own_mask, $self->{reachable_ips})
#   );
#}

#digraph->add_gateway($_) for @{$self->{gws}};

#digraph->print();

### TEST ALL LIBS

# test local linux_generic
my $self = self->new();
# print STDERR Dumper($self);

my $own_ip = $self->{own_ips}->[0]->{ip} // die "Can't obtain self IP";
if (1 < @{ $self->{own_ips} }) {
   digraph->add_router(map { $_->{ip} } @{ $self->{own_ips} });
} else {
   my $ip = @{ $self->{own_ips} }[0]->{ip};
   my $mask = common->ip_to_mask( @{ $self->{own_ips} }[0]->{mask} );
   my $net = Net::Netmask->new("$ip/$mask")->base();
   digraph->add_hosts_in_net("$net/$mask", $ip);
}

for (@{ $self->{own_ips} }) {
   my @ips = ();
   my $ip = $_->{ip};
   my $mask = common->ip_to_mask( $_->{mask} );
   my $net = Net::Netmask->new("$ip/$mask")->base();

   for (@{ $self->{reachable_ips} }) {
      my $remote_net = Net::Netmask->new("$_->{ip}/$mask")->base();
      if ($net eq $remote_net) {
         digraph->add_hosts_in_net("$net/$mask", $_->{ip});
         $_->{net} = $net;
         $_->{mask} = $mask;
      }
   }
}

for my $i (@{ $self->{reachable_ips} }){
   my $ip = $i->{ip};

   next unless defined $HOSTS{$ip};

   my $remote = remote->new($ip, $HOSTS{$ip}->{username}, $HOSTS{$ip}->{password}, \%HOSTS);

   # print STDERR Dumper($remote->{own_ips});
   if (1 < @{ $remote->{own_ips} }) {
      digraph->add_router(map { $_->{ip} } @{ $remote->{own_ips} });
   }

   for (@{ $remote->{own_ips} }) {
      my $ip = $_->{ip};
      my $mask = common->ip_to_mask( $_->{mask} );
      my $net = Net::Netmask->new("$ip/$mask")->base();

      for (@{ $remote->{reachable_ips} }) {
         my $remote_net = Net::Netmask->new("$_->{ip}/$mask")->base();
         if ($net eq $remote_net) {
            digraph->add_hosts_in_net("$net/$mask", $_->{ip});
            $_->{net} = $net;
            $_->{mask} = $mask;
         }
      }

   }
}
#digraph->add_gateway($_) for @{$self->{gws}};

# print STDERR Dumper($self);
digraph->print();

# test remote cisco_generic
#my $tmp_ip = "192.168.2.173";
#my $self_remote = remote->new($tmp_ip, $HOSTS{$tmp_ip}->{username}, $HOSTS{$tmp_ip}->{password}, \%HOSTS);
#print Dumper($self_remote);

# test remote linux_generic
# my $tmp_ip = "192.168.2.24";
# my $self_remote2 = remote->new($tmp_ip, $HOSTS{$tmp_ip}->{username}, $HOSTS{$tmp_ip}->{password}, \%HOSTS);
# print Dumper($self_remote2);

# test remote bsd_generic
#my $tmp_ip = "192.168.2.58";
#my $self_remote3 = remote->new($tmp_ip, $HOSTS{$tmp_ip}->{username}, $HOSTS{$tmp_ip}->{password}, \%HOSTS);
#print Dumper($self_remote3);

# test remote sunos_generic
#my $tmp_ip = "192.168.2.3";
#my $self_remote4 = remote->new($tmp_ip, $HOSTS{$tmp_ip}->{username}, $HOSTS{$tmp_ip}->{password}, \%HOSTS);
#print Dumper($self_remote4);

# print STDERR "End of scan.\n";

=head1 FUNCTIONS

=over 4

=cut

=item f()
   piu piu

=cut

#code

=back

=head1 DEPENDENCIES

#TODO
   nmap >= 5.0

=head1 AUTHORS

Originally developed by Lev Koznov and Sergey Zhmylove.
This program is free software distributed AS-IS. 
You can redistribute it and/or modify it under terms of a licence
bundled within this package.
Copyright, 2017.

=cut
