#!/usr/bin/perl
#use diagnostics;

# mash -- the mail shell, patterned after mush.
# Phase II time: 25 hours

# %close = ( '[', ']', '(', ')', '{', '}', '<', '>', '*', '*' );
# 
# sub delim_format {
#  my($id, $del, $default) = @_;
#  if (!($id =~ /\S/)) {
#    $del = '*'; $id = $default;
#  }
#  return("${del}${md}${id}${me}$close{$del}");
#}

# msglist system may need overhaul; GetOptions doesn't load arrays easily
# todo: see if there should be a msglist function, or if everyone should
# handle it themselves.  range conversion in lists.

# user functions?
# headers use msglist, display status
# mark.  mail/reply fix.
# PGP recognition, automation.

#so we know where to save config.h
$codedir=".";
if ($0 =~ m,^(.*)/[^/]+$,) { unshift(@INC, $1, "$1/", "/home/damien/src/mash"); $codedir=$1;}
unshift (@INC, "~", ".");

require 5;
use strict;
use vars qw($rcfile $home $from %set $editor $mbox $pager $pgpass $curmsg
$sent $received $mailsize $wdir $mailtime @mailbox @msglist %aliases %cmd
%dispatch %set $codedir);

require ".mashrc";
require "cli.pl";
require "comm.pl";
require "slurp.pl";

use Getopt::Long;
$Getopt::Long::ignorecase= 0;
$Getopt::Long::order= $PERMUTE;

loadenv();
readrc();

exit 0 if parseline(); # if invoked in sending mode
slurp(); # read in mailbox
cli();  # will exit from here; main code over.

##################

sub readrc {
    require $rcfile if -e "$home/.mashrc";
    $from= $set{From};
}        

sub loadenv {
    $home = $ENV{HOME};    
    #editor= "/usr/bin/vi";
    $editor = $ENV{EDITOR};
    $editor = $ENV{VISUAL};
    $mbox = $ENV{MAIL};
    $pager= "/usr/bin/more";
    $pager= $ENV{PAGER};
    $pgpass= "";
    $curmsg= 0;
    $sent= "$home/Mail/sent";
    $received= "$home/Mail/received";
    $rcfile= "$home/.mashrc";

    use Cwd;
    $wdir= substr ($mbox, 0, rindex($mbox,'/')) or cwd();
}

sub printhelp {
    0;
}

sub parseline {
    local @ARGV= @ARGV;
    my @tmpopts=@ARGV;
    use vars qw($opt_f);
    local $opt_f;
    my $i= GetOptions('f:s','b=s','c=s','s:s');

    if (@ARGV) {  # the leftover argument should be our address
        @ARGV= @tmpopts;
        mail();   # let mail() figure it out
        return 1;   # and that's all we wanted to do
    }

    if (defined $opt_f) {
        if ($opt_f eq '1') {
            $mbox= $received;
        } else {
            $mbox = $opt_f;
        } 
    }
    loadmail();
    return 0;
}

sub loadmail {
    warn "$mbox is empty\n" if -z $mbox;
    warn "$mbox: No such file or directory\n" and return 0 if !-e $mbox;
    open (MAIL,"$mbox") or warn "Trouble opening $mbox\n";
    $mailsize= -s $mbox;
}
