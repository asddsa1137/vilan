#!/usr/bin/perl
 
package gnuscreen;
 
use strict;
use v5.18;
use warnings;
no warnings 'experimental';
binmode STDOUT, ':utf8';
 
use Data::Validate::IP;
 
my $USAGE  = ($0 // '') . " tunnel_no new_dest";
my $KEY    = "/usr/local/dyndns/ssh_key";
my $USER   = "dyndns";
my $HOST   = "10.0.0.1";
my $SSH    = "/usr/bin/ssh -i $KEY -e none $USER\@$HOST";
my $SCREEN = "/usr/bin/screen";
 
sub new {
   my $class = shift;
   my $args = shift;
 
   $KEY    = $args->{key}    // $KEY;
   $USER   = $args->{user}   // $USER;
   $HOST   = $args->{host}   // $HOST;
   $SSH    = $args->{ssh}    // $SSH;
   $SCREEN = $args->{screen} // $SCREEN;
 
   return bless {}, $class;
}
 
sub DIE {
   die "@_" || $USAGE;
}
 
sub CMD($) {
   (my $stuff = $_[0]) =~ s/'/'"'"'/;
   `$SCREEN -S $S_NAME -X stuff \'$stuff\n\'`;
}

sub create($$$$$) {
   # args: self, user, password, screen location, openssh location
   #TODO
   # 
   # `$SCREEN -c /dev/null -dmS $S_NAME $SSH`;
}

sub destroy {
   #TODO
}
