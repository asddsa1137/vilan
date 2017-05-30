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
use Data::Dumper;

=encoding utf-8

=head1 NAME

=head1 FUNCTIONS

=over 4

=cut

sub check_local {
   return `uname -s` =~ "Linux";
}

sub check_remote($$$$$) {
   shift; #self
   my $target_ip = shift;
   my $HOSTS = shift;
   my $username = $HOSTS->{"$target_ip"}->{username};
   my $password = $HOSTS->{"$target_ip"}->{password};
   my $session = Libssh::Session->new();
   if (!$session->options(host => $target_ip, user => $username, port => 22)) {
      return 0;
   }

   if ($session->connect() != SSH_OK) {
      print STDERR "Can't connect to $target_ip using ssh.";
      print STDERR "Continuing without remote scan of this host.\n";
      return 0;
   }

   if ($session->auth_password(password => $password) != SSH_AUTH_SUCCESS) {
      print STDERR "Incorrent username or password for host $target_ip.\n";
      print STDERR "Continuing without remote scan of this host.\n";
      return 0;
   }

   my %rc = %{ $session->execute_simple(
         cmd => 'uname -s', timeout => 60, timeout_nodata => 30
      )};

   $session->disconnect();

   return $rc{stdout} =~ "Linux";
}

sub get_self_local {
   my (%self, @own_ips_AoH, @reachable_ips_AoH, @routes_AoH);


   chomp(my @self_addrs = `export LC_ALL=C LANG=C; (ip a || ifconfig -a) 2>/dev/null |awk '!/127.[0-9]*.[0-9]*.[0-9]*/ && \$1=="inet"{print}'`);

# find all visible ips
   for (@self_addrs) {
      my ($ip, $mask, $numerical_mask);

      ($ip, $mask) = m{addr:([\d.]+).*mask:([\d.]+)}i unless $ip;
      ($ip, $mask) = m{inet ([\d.]+)/([\d]+)}i unless $ip;
      next unless $ip;

      chomp(my $MAC = `export LC_ALL=C LANG=C; ifconfig -a |grep -B1 '\\<$ip\\>' |awk 'NR==1{print \$NF}'`);
      $mask = common->mask_to_ip($mask);

      $numerical_mask = common->ip_to_mask($mask);

# check for nmap presence and ping entire subnet
      chomp(my $nmap_pres = `which nmap`);
      if ($nmap_pres eq "") {
         if($numerical_mask ge 20) {
            $self{nmap_pres} = "0";
            my $test_ip = new Net::IP(new Net::Netmask("$ip/$numerical_mask")->base()."/".$numerical_mask);
            do {
               system("ping -c 1 -W 1 ".$test_ip->ip()." >/dev/null &");
            } while (++$test_ip);
            sleep 5;
         }
         else {
            print STDERR "OMG! Network $ip/$numerical_mask is too big. Max is /20\n";
            print STDERR "Install nmap on local machine for more accurate scan result.\n";
         }
      }
      else {
         $self{nmap_pres} = "1";
         `export LC_ALL=C LANG=C; nmap -sn -n $ip\/$numerical_mask`;
      }

      my $own_ips->{ip} = $ip;
      $own_ips->{mask} = $mask;
      $own_ips->{mac} = $MAC;
      push @own_ips_AoH, $own_ips;
   }
   $self{own_ips} = \@own_ips_AoH;

   for(`export LC_ALL=C LANG=C; arp -n |awk 'NR>1 && !/incomplete/ {print \$1 " " \$3}'`) {
      /^([\d.]+) ([a-f:\d]+)\n?$/ && push @reachable_ips_AoH, { ip=>$1, mac=>$2 };
   }

   $self{reachable_ips} = \@reachable_ips_AoH;

# determine routes
   for(`export LC_ALL=C LANG=C; netstat -rn |awk '\$4~/G/{print \$1" "\$2" "\$3}'`) {
      /([\d.]+) ([\d.]+) ([\d.]+)/ && push @routes_AoH, { network=>$1, mask=>$3, host=>$2 };
   }

   $self{routes} = \@routes_AoH;

   return \%self;
}

sub get_self_remote($$$$) {
   shift; #self
   my $target_ip = shift;
   my $HOSTS = shift;
   my $username = $HOSTS->{"$target_ip"}->{username};
   my $password = $HOSTS->{"$target_ip"}->{password};
   my (%self, @own_ips_AoH, @reachable_ips_AoH, @routes_AoH);
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
         cmd => 'export LC_ALL=C LANG=C; (ip a || ifconfig -a) 2>/dev/null |awk \'!/127.[0-9]*.[0-9]*.[0-9]*/ && $1=="inet"{print}\'', timeout => 60, timeout_nodata => 30
      )};

   chomp(my @self_addrs = split '\n', $rc{stdout});

# check for nmap presence
   %rc = %{ $session->execute_simple(
         cmd => 'which nmap', timeout => 60, timeout_nodata => 30
      )};
   chomp(my $nmap_pres = $rc{stdout});

# find all visible ips

   for (@self_addrs) {
      my ($ip, $mask, $numerical_mask);
   
      ($ip, $mask) = m{addr:([\d.]+).*mask:([\d.]+)}i unless $ip;
      ($ip, $mask) = m{inet ([\d.]+)/([\d]+)}i unless $ip;
      next unless $ip;

      %rc = %{ $session->execute_simple(
            cmd => "export LC_ALL=C LANG=C; ifconfig -a |grep -B1 '\\<$ip\\>' |awk 'NR==1{print \$NF}'", timeout => 60, timeout_nodata => 30
         )};
      chomp(my $MAC = $rc{stdout});

      $mask = common->mask_to_ip($mask);

      $numerical_mask = common->ip_to_mask($mask);

      # ping entire subnet
      
      if ($nmap_pres eq "") {
         if($numerical_mask ge 20) {
            my @AoH;
            $self{nmap_pres} = "0";
            my $ip_to_ping = new Net::IP(new Net::Netmask("$ip/$numerical_mask")->base()."/".$numerical_mask);
            do {
               my $command_hash->{cmd} = ("ping -c 1 -W 1 ".$ip_to_ping->ip()." >/dev/null &");
               push @AoH, $command_hash;
            } while (++$ip_to_ping);
            $session->execute(commands => \@AoH, timeout => 10, timeout_nodata => 10, parallel => 5);
            sleep 5; #wait for ping end on remote host
         }
         else {
            print STDERR "OMG! Network $ip/$numerical_mask is too big. Max is /20\n";
            print STDERR "Install nmap on $target_ip for more accurate scan result.\n";
         }
      }
      else {
         $self{nmap_pres} = "1";
         $session->execute_simple(cmd => "export LC_ALL=C LANG=C; nmap -sn -n $ip/$numerical_mask",
            timeout => 60, timeout_nodata => 30);
      }


      my $own_ips->{ip} = $ip;
      $own_ips->{mask} = $mask;
      $own_ips->{mac} = $MAC;
      push @own_ips_AoH, $own_ips;
   }

   $self{own_ips} = \@own_ips_AoH;

   %rc = %{ $session->execute_simple(
         cmd => "export LC_ALL=C LANG=C; arp -n |awk 'NR>1 && !/incomplete/ {print \$1 \" \" \$3}'", timeout => 60, timeout_nodata => 30
      )};
   chomp(my @arp_output = split '\n', $rc{stdout});
   for(@arp_output) {
      /^([\d.]+) ([a-f:\d]+)\n?$/ && push @reachable_ips_AoH, { ip=>$1, mac=>$2 };
   }

   $self{reachable_ips} = \@reachable_ips_AoH;

# determine routes
   %rc = %{ $session->execute_simple(
         cmd => "export LC_ALL=C LANG=C; netstat -rn |awk '\$4~/G/{print \$1\" \"\$2\" \"\$3}'", timeout => 60, timeout_nodata => 30
      )};
   chomp(my @routes = split '\n', $rc{stdout});

   for(@routes) {
      /([\d.]+) ([\d.]+) ([\d.]+)/ && push @routes_AoH, { network=>$1, mask=>$3, host=>$2 };
   }

   $self{routes} = \@routes_AoH;

   $session->disconnect();
   return \%self;
}


1;

=back

=cut
