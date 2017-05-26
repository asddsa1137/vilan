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

my $self = self->new();

#print Dumper($self, "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
#while (my ($own_ip, $own_mask) = each $self->{own_ips}) {
#   digraph->add_connection($own_ip, 
#      common->find_ips_in_subnet($own_ip, $own_mask, $self->{reachable_ips})
#   );
#}

#digraph->add_gateway($_) for @{$self->{gws}};

#digraph->print();

my $tmp_ip = "192.168.2.24";

my $self_remote = remote->new($tmp_ip, $HOSTS{$tmp_ip}->{username}, $HOSTS{$tmp_ip}->{password});
# output is bugged!
#while (my ($own_ip, $own_mask) = each $self->{own_ips}) {
#   digraph->add_connection($own_ip, 
#      common->find_ips_in_subnet($own_ip, $own_mask, $self->{reachable_ips})
#   );
#}

#digraph->add_gateway($_) for @{$self->{gws}};

#digraph->print();
print Dumper($self_remote);

print "End of scan.\n";

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
