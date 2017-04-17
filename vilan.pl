#!/usr/bin/perl

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

=encoding utf-8

=head1 NAME

B<vilan> -- LAN topology visualizer

=head1 SYNOPSIS

   vilan [ -c config.pm ]

Here will be some examples of syntax and all parameters

=head1 DESCRIPTION

The B<vilan> utility scans network and makes it's topology in digraph format.

=cut 

our %HOSTS;
#TODO parse arguments [ -c config.pl ]
my $config_file = './config.pl';
unless (my $rc = do $config_file) {
   warn "couldn't parse $config_file: $@" if $@;
   warn "couldn't do $config_file: $!" unless defined $rc;
   warn "couldn't run $config_file" unless $rc;
}

=head1 FUNCTIONS

=over 4

=cut

=item f()
   piu piu

=cut

#code

=back

=head1 DEPENDENCIES

#TODO
   nmap >= 5.0

=head1 AUTHORS

Originally developed by Lev Koznov and Sergey Zhmylove.
This program is free software distributed AS-IS. 
You can redistribute it and/or modify it under terms of a licence
bundled within this package.
Copyright, 2017.

=cut
