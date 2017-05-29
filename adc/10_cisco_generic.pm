#!/usr/bin/perl
package cisco_generic;

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use adc::common;
use Libssh::Session qw(:all);
use Net::IP;
use Net::Netmask;
use Net::Telnet::Cisco;
use Data::Dumper;

=encoding utf-8

=head1 NAME

=head1 FUNCTIONS

=over 4

=cut

sub check_local {
   # Never will be used
   return 0;
}

sub check_remote($$$$$) {
   shift; #self
   my $target_ip = shift;
   my $HOSTS = shift;
   my $username = $HOSTS->{"$target_ip"}->{username};
   my $password = $HOSTS->{"$target_ip"}->{password};

   my $session = Net::Telnet::Cisco->new(Host => "$target_ip");
   $session->login("$username", "$password");
   my @output = $session->cmd('sh ver | i IOS');

   $session->close;
   return $output[0] =~ "IOS";
}

sub get_self_local {
   # Never will be used
   return {};
}

sub get_self_remote($$$$) {
   shift; #self
   my $target_ip = shift;
   my $HOSTS = shift;
   my $username = $HOSTS->{"$target_ip"}->{username};
   my $password = $HOSTS->{"$target_ip"}->{password};
   my (%self, @own_ips_AoH, @reachable_ips_AoH);

   my $session = Net::Telnet::Cisco->new(Host => "$target_ip");
   $session->login("$username", "$password");

   # get ip configuration
   my @self_addrs = $session->cmd('sh int | i Internet address');

# find all visible ips

   for (@self_addrs) {
      my ($ip, $mask, $numerical_mask);
   
      ($ip, $mask) = m{Internet address is ([\d.]+)/([\d]+)}i unless $ip;
      next unless $ip;

      $mask = common->mask_to_ip($mask);
      $numerical_mask = common->ip_to_mask($mask);

      (my $s_ip = $ip) =~ s/\./\\./g;
      (join "", $session->cmd('sh int'))=~m{address is ([0-9a-f.]+)[^I]*?Internet address is $s_ip}s;
      my $MAC = $1;

      my $ip_to_ping = new Net::IP(new Net::Netmask("$ip/$numerical_mask")->base()."/".$numerical_mask);
      ++$ip_to_ping; # skip network address

      #if($numerical_mask ge 20) {
      #   $session->enable(Name => $HOSTS->{"$target_ip"}->{enable_user}, Password => $HOSTS->{"$target_ip"}->{enable_password});
      #   if ($session->is_enabled) {
      #      print STDERR "Filling ARP table on Cisco [$ip]. It may take a while...\n";
      #      do {
      #         eval {
      #            $session->cmd("ping ".$ip_to_ping->ip()." ti 1 re 1");
      #         };
      #      } while (++$ip_to_ping);
      #   }
      #   $session->disable;
      #}
      #else {
      #   print STDERR "OMG! Network $ip/$numerical_mask is too big to ping on Cisco [$ip]. Max is /20\n";
      #   print STDERR "You will get only hosts existing in Cisco ARP table for subnet $ip/$numerical_mask.\n";
      #}

      my $own_ips->{ip} = $ip;
      $own_ips->{mask} = $mask;
      $own_ips->{mac} = mac_cisco_to_unix($MAC);
      push @own_ips_AoH, $own_ips;
   }

   $self{own_ips} = \@own_ips_AoH;

   # get all reachable ips from ARP table
   my @arp = $session->cmd('sh ip arp | exclude Proto|Inco');
   for($session->cmd('sh ip arp | exclude Proto|Inco')) {
      /Internet +([\d.]+) +[\d\-]+ +([a-f\d.]+)/ && push @reachable_ips_AoH, { ip=>$1, mac=>mac_cisco_to_unix($2) };
   }

   $self{reachable_ips} = \@reachable_ips_AoH;

# determine routes
# TODO

   $session->close;
   return \%self;
}

sub mac_cisco_to_unix($) {
   my $MAC = shift;
   $MAC=~s/\.//g;
   $MAC=~s/^(..)(..)(..)(..)(..)(..)/$1:$2:$3:$4:$5:$6/;
   return $MAC;
}


1;

=back

=cut
