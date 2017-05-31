#!/usr/bin/perl
package sunos_generic;

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
   return `uname -s` =~ "SunOS";
}

sub check_remote($$$$) {
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
      print STDERR "Incorrent username or password for host $target_ip. BSD\n";
      print STDERR "Continuing without remote scan of this host.\n";
      return 0;
   }

   my %rc = %{ $session->execute_simple(
         cmd => '/usr/bin/uname -s', timeout => 60, timeout_nodata => 30
      )};

   $session->disconnect();

   return $rc{stdout} =~ "SunOS";
}

sub get_self_local {
   my (%self, @own_ips_AoH, @reachable_ips_AoH, @routes_AoH);
   print "GETTING SELF\n";

# check csh
   if(`echo \$0` =~ "csh") {
      print STDERR("csh is not supported. Exiting remote data collection");
      return {};
   }

# get ip configuration
   
   chomp(my @self_addrs = `export LC_ALL=C LANG=C; /sbin/ifconfig -a 2>/dev/null |/usr/bin/awk '!/127.[0-9]*.[0-9]*.[0-9]*/ && \$1=="inet"{print}'`);

# find all visible ips
   for (@self_addrs) {
      my ($ip, $mask, $numerical_mask);

      ($ip, $mask) = m{inet ([\d.]+).*netmask ([^ ]+)}i unless $ip;
      next unless $ip;

      chomp(my $MAC = `export LC_ALL=C LANG=C; /sbin/ifconfig -a |/usr/sbin/arp -an |/usr/bin/grep " $ip " |/usr/bin/awk '{print \$NF}`);
      $mask = common->mask_to_ip($mask);

      $numerical_mask = common->ip_to_mask($mask);

# check for nmap presence and ping entire subnet
      chomp(my $nmap_pres = `which nmap`);
      if ($nmap_pres =~ "not found") {
         if($numerical_mask ge 20) {
            $self{nmap_pres} = "0";
            my $test_ip = new Net::IP(new Net::Netmask("$ip/$numerical_mask")->base()."/".$numerical_mask);
            do {
               system("/usr/sbin/ping ".$test_ip->ip()." 1 >/dev/null &");
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

   for(`export LC_ALL=C LANG=C; /usr/sbin/arp -an |/usr/bin/awk '\$NF~/[a-f\\d:]/ && !/[MS]/ {print \$2 " " \$NF}'`) {
      /^([\d.]+) ([a-f:\d]+)\n?$/ && push @reachable_ips_AoH, { ip=>$1, mac=>$2 };
   }

   $self{reachable_ips} = \@reachable_ips_AoH;

# determine routes
   for(`export LC_ALL=C LANG=C; /usr/bin/netstat -rn |/usr/bin/awk '\$3~/G/{print \$1" "\$2}'`) {
      /([\d.]+)\/([\d]+) ([\d.]+)/ && push @routes_AoH, { network=>$1, mask=>common->ip_to_mask($2), host=>$3 };
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

# check csh
   my %rc = %{ $session->execute_simple(
         cmd => 'echo $0', timeout => 60, timeout_nodata => 30
      )};

   if($rc{stdout} =~ "csh") {
      print STDERR("csh is not supported. Exiting remote data collection");
      return {};
   }

# get ip configuration

   %rc = %{ $session->execute_simple(
         cmd => "export LC_ALL=C LANG=C; /sbin/ifconfig -a 2>/dev/null |/usr/bin/awk '!/127.[0-9]*.[0-9]*.[0-9]*/ && \$1==\"inet\"{print}'", timeout => 60, timeout_nodata => 30
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
   
      ($ip, $mask) = m{inet ([\d.]+).*netmask ([^ ]+)}i unless $ip;
      next unless $ip;

      %rc = %{ $session->execute_simple(
            cmd => "export LC_ALL=C LANG=C; /sbin/ifconfig -a |/usr/sbin/arp -an |/usr/bin/grep \" $ip \" |/usr/bin/awk '{print \$NF}'", timeout => 60, timeout_nodata => 30
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
               my $command_hash->{cmd} = ("/usr/sbin/ping ".$ip_to_ping->ip()." 1 >/dev/null &");
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
         cmd => "export LC_ALL=C LANG=C; /usr/sbin/arp -an |/usr/bin/awk '\$NF~/[a-f\\d:]/ && !/[MS]/ {print \$2 \" \" \$NF}'", timeout => 60, timeout_nodata => 30
      )};
   chomp(my @arp_output = split '\n', $rc{stdout});
   for(@arp_output) {
      /^([\d.]+) ([a-f:\d]+)\n?$/ && push @reachable_ips_AoH, { ip=>$1, mac=>$2 };
   }

   $self{reachable_ips} = \@reachable_ips_AoH;

# determine routes
   %rc = %{ $session->execute_simple(
         cmd => "export LC_ALL=C LANG=C; /usr/bin/netstat -rn |/usr/bin/awk '\$3~/G/{print \$1\" \"\$2}'", timeout => 60, timeout_nodata => 30
      )};
   chomp(my @routes = split '\n', $rc{stdout});
   for(@routes) {
      s/default/0.0.0.0\/0/;
      if(/([\d.]+)\/([\d]+) ([\d.]+)/) {  
         push @routes_AoH, { network=>$1, mask=>common->mask_to_ip($2), host=>$3 };
      }
      else {
         /([\d.]+) ([\d.]+)/ && push @routes_AoH, { network=>$1, mask=>"255.255.255.255", host=>$2 };
      }
   }

   $self{routes} = \@routes_AoH;

   $session->disconnect();
   return \%self;
}

1;

=back

=cut
