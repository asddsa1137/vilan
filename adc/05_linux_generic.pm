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
   chomp(my @a = `(ip a || ifconfig -a) 2>/dev/null |awk '\$1=="inet"{print}' |grep -v '127.0.0.1'`);
   my %ips;

   for (@a) {
      my ($ip, $mask, $mask_for_nmap);

      ($ip, $mask) = m{addr:([\d.]+).*mask:([\d.]+)}i unless $ip;
      ($ip, $mask) = m{inet ([\d.]+)/([\d]+)}i unless $ip;
      return ("xxx") unless $ip;

      $mask = common->mask_to_ip($mask);

      $mask_for_nmap = common->ip_to_mask($mask);
      `nmap -sn $ip\/$mask_for_nmap`;
      chomp(my @b = `arp -n |grep -v "incomplete" |awk 'NR>1 {print \$1}'`);
      for (@b) {
         $ips{$_} = $mask;
      }

      $ips{$ip} = $mask;
   }

   return %ips;
}

1;

=back

=cut
