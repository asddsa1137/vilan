#!/usr/bin/perl

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use adc::adc;

=encoding utf-8

=head1 NAME

=head1 FUNCTIONS

=over 4

=cut

package bsd_generic;

=item B<new()>

   return: an instance of self object

This function is ctor.

=cut

sub new {
   my $self = shift;
   return bless {}, $self;
}

sub check {
   return `uname -s` =~ m{BSD}i;
}

sub get_ips {
   chomp(my @a = `/sbin/ifconfig -a 2>/dev/null |awk '\$1=="inet"{print}'`);
   my %ips;

   for (@a) {
      my ($ip, $mask);

      ($ip, $mask) = m{inet ([\d.]+).*netmask ([^ ]+)}i unless $ip;

      $ip = "xxx" unless $ip;

      $ips{$ip} = adc->mask_to_ip($mask);
   }

   return %ips;
}

1;

=back

=cut
