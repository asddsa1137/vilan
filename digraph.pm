#!/usr/bin/perl

use strict;
use warnings;

package digraph;

=head1 FUNCTIONS

=over 4

=item add_connection
   arg0: root elemnt
   arg1 ... argN: element to connect with

=cut

my (@connections, @gateways, @hosts, @routers);
my $counter = 0;
my $re = "";
my %NETS;

sub add_connection {
   shift; #self
   my $root = shift;
   for (@_) {
      if ($_ ne $root) {
         push @connections, "\"$root\" -> \"$_\" [arrowhead=\"none\"];\n";
      } else {
         push @connections, "\"$root\";\n";
      }
   }
}

sub add_router {
   shift; #self
   
   push @routers, "subgraph cluster$counter {label=\"host_$counter\";\n" .
   (join "\n", map { "\"$_\";" } @_) . "}\n";

   $counter++;

   ($re = join "|", $re, @_) =~ s/\./\./g;
}

sub add_hosts_in_net {
   shift; #self
   my $net = shift;
   push @{$NETS{$net}}, @_;
}

# sub add_host {
#    shift; #self
# 
#    push @hosts, "subgraph cluster_$counter {label=\"host_$counter\";\n" .
#    (join "\n", map { "\"$_\";" } @_) . "}\n";
# 
#    $counter++;
# }

sub add_gateway {
   shift; #self
   my $gateway = shift;
   push @gateways, "node [shape = doublecircle]; \"$gateway\";\n";
}

sub print {
   shift; #self
   print "digraph ", shift // "G", " {\n";
   print for @gateways;
   # print "node [shape = circle];\n";
   # print for grep ! /"(?:$re)"/, @connections;
   # print for @hosts;
   print for @routers;
   # print STDERR "RE: [$re]";
   for (keys %NETS) {
      print "subgraph cluster_", ($_ =~ s/[.\/]/_/gr), " {label=\"$_\";style=filled;\n";
      print join "", map { "\"$_\" [color=white,style=filled];" } grep ! /^(?:$re)$/, @{ $NETS{$_} };
      print "\n}\n";
   }

   for my $net (keys %NETS) {
      for (split /\|/, $re) {
         # print STDERR "[[[ $_ ]]]";
         next unless $_;
         my $remote_net = Net::Netmask->new("$net")->base();
         my $suffix = (split "/", $net)[1];
         my $net = Net::Netmask->new("$_/$suffix")->base();
         (my $txt_net = "$net/$suffix") =~ s/[.\/]/_/g;
         print "\"$_\" -> cluster_$txt_net [arrowhead=\"none\"];" if ($net eq $remote_net);
      }
   }
   print "}\n";
}

1;

=back
