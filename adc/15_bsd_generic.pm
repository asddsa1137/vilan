#!/usr/bin/perl

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use adc::common;

=encoding utf-8

=head1 NAME

=head1 FUNCTIONS

=over 4

=cut

package bsd_generic;

sub check {
   return `uname -s` =~ m{BSD}i;
}

sub get_self {
   chomp(my @self_addrs = `/sbin/ifconfig -a 2>/dev/null |awk '\$1=="inet"{print}'`);
   my (%self, %reachable_ips, %own_ips);

   for (@self_addrs) {
      my ($ip, $mask, $mask_for_nmap);

      ($ip, $mask) = m{inet ([\d.]+).*netmask ([^ ]+)}i unless $ip;
      next unless $ip;

      $mask = common->mask_to_ip($mask);

      $mask_for_nmap = common->ip_to_mask($mask);
      `nmap -sn $ip\/$mask_for_nmap`;
      chomp(my @arp = `arp -an |awk '!/incomplete/{print \$2}' |tr -d '()'`);
      $reachable_ips{$_} = $mask for @arp;

      $own_ips{$ip} = $mask;
   }
   $self{reachable_ips} = \%reachable_ips;
   $self{own_ips} = \%own_ips;

# determine default GWs
   chomp(my @gws = `netstat -rn |awk '\$3~/G/{print \$2}'`);
   $self{gws} = \@gws;

   return \%self;
}

1;

=back

=cut
