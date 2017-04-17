#!/usr/bin/perl

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use adc::adc;
use adc::05_linux_generic;

=encoding utf-8

=head1 NAME

=head1 FUNCTIONS

=over 4

=cut

package self;

=item B<new()>

   return: an instance of self object

This function is ctor.

=cut

my $self = self->new();

sub new($) {
   my $self = shift;
   if (linux_generic->check()) {
      print linux_generic->get_ips();
   }
   return bless {}, $self;
}



# 1;

=back

=cut
