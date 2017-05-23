#!/usr/bin/perl
package linux_generic;

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

=encoding utf-8

=head1 NAME

=head1 FUNCTIONS

=over 4

=cut

sub check_local {
   return `uname -s` =~ "Linux";
}

sub check_remote($$$$) {
   shift; #self
   my $target_ip = shift;
   my $username = shift;
   my $password = shift;
   my $session = Libssh::Session->new();
   if (!$session->options(host => $target_ip, user => $username, port => 22)) {
      return 0;
   }

   if ($session->connect() != SSH_OK) {
      return 0;
   }

   if ($session->auth_password(password => $password) != SSH_AUTH_SUCCESS) {
      print STDERR "Incorrent username or password for host $target_ip.\n";
      return 0;
   }

   my %rc = %{ $session->execute_simple(
         cmd => 'uname -s', timeout => 60, timeout_nodata => 30
      )};

   $session->disconnect();

   return $rc{stdout} =~ "Linux";
}

sub get_self_local {
   my (%self, %reachable_ips, %own_ips);


   chomp(my @self_addrs = `(ip a || ifconfig -a) 2>/dev/null |awk '!/127.0.0.1/ && \$1=="inet"{print}'`);

# find all visible ips
   for (@self_addrs) {
      my ($ip, $mask, $numerical_mask);

      ($ip, $mask) = m{addr:([\d.]+).*mask:([\d.]+)}i unless $ip;
      ($ip, $mask) = m{inet ([\d.]+)/([\d]+)}i unless $ip;
      next unless $ip;

      $mask = common->mask_to_ip($mask);

      $numerical_mask = common->ip_to_mask($mask);

      if($numerical_mask lt 20) {
         print("OMG! Network $ip/$numerical_mask is too big. Install nmap on local device.\n");
         return {};
      }

# check for nmap presence and ping entire subnet
      chomp(my $nmap_pres = `which nmap`);
      if ($nmap_pres eq "") {
         $self{nmap_pres} = "0";
         my $test_ip = new Net::IP(new Net::Netmask("$ip/$numerical_mask")->base()."/".$numerical_mask);
         do {
            system("ping -c 1 -W 1 ".$test_ip->ip()." >/dev/null &");
         } while (++$test_ip);
         sleep 5
      }
      else {
         $self{nmap_pres} = "1";
         `nmap -sn -n $ip\/$numerical_mask`;
      }

      chomp(my @arp = `arp -n |awk 'NR>1 && !/incomplete/ {print \$1}'`);
      $reachable_ips{$_} = $mask for @arp;

      $own_ips{$ip} = $mask;
   }
   $self{reachable_ips} = \%reachable_ips;
   $self{own_ips} = \%own_ips;

# determine default GWs
   chomp(my @gws = `netstat -rn |awk '\$4~/G/{print \$2}'`);
   $self{gws} = \@gws;

   return \%self;
}

sub get_self_remote($$$$) {
   shift; #self
   my $target_ip = shift;
   my $username = shift;
   my $password = shift;
   my (%self, %reachable_ips, %own_ips);
   my $session = Libssh::Session->new();

   if (!$session->options(host => $target_ip, user => $username, port => 22)) {
      return 0;
   }

   if ($session->connect() != SSH_OK) {
      return 0;
   }

   if ($session->auth_password(password => $password) != SSH_AUTH_SUCCESS) {
      return 0;
   }


# get ip configuration

   my %rc = %{ $session->execute_simple(
         cmd => '(ip a || ifconfig -a) 2>/dev/null |awk \'!/127.0.0.1/ && $1=="inet"{print}\'', timeout => 60, timeout_nodata => 30
      )};

   chomp(my @self_addrs = split '\n', $rc{stdout});

# find all visible ips

   for (@self_addrs) {
      my ($ip, $mask, $numerical_mask);
   
      ($ip, $mask) = m{addr:([\d.]+).*mask:([\d.]+)}i unless $ip;
      ($ip, $mask) = m{inet ([\d.]+)/([\d]+)}i unless $ip;
      next unless $ip;

      $mask = common->mask_to_ip($mask);

      $numerical_mask = common->ip_to_mask($mask);

# check for nmap presence and ping entire subnet
      %rc = %{ $session->execute_simple(
            cmd => 'which nmap', timeout => 60, timeout_nodata => 30
         )};
      chomp(my $nmap_pres = $rc{stdout});

      if ($nmap_pres eq "") {
         if($numerical_mask ge 20) {
            my @AoH;
            $self{nmap_pres} = "0";
            my $ip_to_ping = new Net::IP(new Net::Netmask("$ip/$numerical_mask")->base()."/".$numerical_mask);
            do {
               my $command_hash->{cmd} = ("ping -c 1 -W 1 ".$ip_to_ping->ip()." >/dev/null/ &");
               push @AoH, $command_hash;
            } while (++$ip_to_ping);
            sleep 5;
         }
         else {
            print STDERR "OMG! Network $ip/$numerical_mask is too big. Max is /20\n";
            print STDERR "Install nmap on $target_ip for more accurate scan result.\n";
         }
      }
      else {
         $self{nmap_pres} = "1";
         $session->execute_simple(cmd => "nmap -sn -n $ip/$numerical_mask",
            timeout => 60, timeout_nodata => 30);
      }

      %rc = %{ $session->execute_simple(
            cmd => "arp -n |awk 'NR>1 && !/incomplete/ {print \$1}'", timeout => 60, timeout_nodata => 30
         )};
      chomp(my @arp = split '\n', $rc{stdout});
      $reachable_ips{$_} = $mask for @arp;

      $own_ips{$ip} = $mask;
   }
   $self{reachable_ips} = \%reachable_ips;
   $self{own_ips} = \%own_ips;

# determine default GWs
   %rc = %{ $session->execute_simple(
         cmd => "netstat -rn |awk '\$4~/G/{print \$2}'", timeout => 60, timeout_nodata => 30
      )};
   chomp(my @gws = split '\n', $rc{stdout});
   $self{gws} = \@gws;

   $session->disconnect();
   return \%self;
}


1;

=back

=cut
