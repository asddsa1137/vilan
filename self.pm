#!/usr/bin/perl

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

my $_dir = "adc";
my %_modules;
eval "use ${_dir}::$_", $_modules{$_} += defined $@ ? 0 : 1 for
map { s,.*/,,; s/.pm$//r } glob "$_dir/*.pm";

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

my %ips = ();

sub new($) {
   my $self = shift;
   my %self;

   my $prefix;
   eval "$_\->check()" and $prefix = $_ for (map { s,^\d+_,,r } keys %_modules);
   exit 2 unless $prefix;

   print "I am $prefix !\n";
   %self = %{ eval "$prefix\->get_self()" };

   return bless \%self, $self;
}

=item B<get_self ()>

   returns { ip => mask } HASH pointer

=cut

1;

=back

=cut
