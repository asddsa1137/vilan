#!/usr/bin/perl

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

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

sub new {
   my $selft = shift;
   return bless {}, $self;
}

1;

=back

=cut
