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

my (@connections, @gateways);

sub add_connection {
   shift; #self
   my $root = shift;
   for (@_) {
      if ($_ ne $root) {
         push @connections, "\"$root\" -> \"$_\";\n";
      } else {
         push @connections, "\"$root\";\n";
      }
   }
}

sub add_gateway {
   shift; #self
   my $gateway = shift;
   push @gateways, "node [shape = doublecircle]; \"$gateway\";\n";
}

sub print {
   shift; #self
   print "digraph ", shift // "G", " {\n";
   print for @gateways;
   print "node [shape = circle];\n";
   print for @connections;
   print "}\n";
}

1;

=back
