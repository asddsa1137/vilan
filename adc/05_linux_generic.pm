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

package linux_generic;

=item B<new()>

   return: an instance of self object

This function is ctor.

=cut

sub new {
   my $self = shift;
   return bless {}, $self;
}

sub check {
   return `uname -s` =~ "Linux";
}

sub get_ips {
   my @a = `(ip a || ifconfig -a) 2>/dev/null |awk '\$1=="inet"{print}'`;
   chomp @a;
   for (@a) {
      my ($ip, $mask);

      ($ip, $mask) = m{addr:([\d.]+).*mask:([\d.]+)}i;
      ($ip, $mask) = m{inet ([\d.]+)/([\d]+)}i unless $ip;
      $ip = "FUCK" unless $ip;

      printf "[%s] [%s]\n", $ip, adc->mask_to_ip($mask);
   }
}

1;

=back

=cut
