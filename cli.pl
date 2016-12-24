use strict; 

sub setprompt {
    my ($min, $hour)= (localtime(time))[1,2];
    $hour %=12;
    if ($hour == 0) {$hour=12;};
    if ($min =~ /^\d$/) {$min= '0'.$min;}
    return "$hour:$min";
}

use Term::ReadLine;
use Text::ParseWords;

sub cli {
    my ($line, $comm);
    $curmsg= 1 if ($#mailbox);
    my $prompt= '"($time) $mbox: #$curmsg of " . $#mailbox . "> "';
    $_="";
    my $time= setprompt();
    my $semi= ';';
    my $pipe= '\|';
    my $space= '\s+';
    my $term= new Term::ReadLine;
    while (defined ($_=$term->readline(eval $prompt))) {
        if (-s $mbox != $mailsize) {
            close MAIL;
            @mailbox=();
            loadmail();
            slurp();
        }
#chop;
        foreach $line (parse_line($semi,1,$_)) {
            @msglist=();
	    my @lines= parse_line($pipe, 1, $line);
            foreach $comm (parse_line($pipe,1,$line)) {
                cli_proc($comm,$space);
            }
        }
    } continue {
        &setprompt;
    }
}

sub cli_proc{
    my $space = pop @_;;
    ($_) = @_;
    if (/^\s*(\d+)\s*$/) {
# just a number, so print the message.
        @ARGV=();
        printmsg($1);;
        return;
    }
    my $cmd;
# 'd3' is valid for 'delete 3'
    /^\s*([a-zA-z]+)\s*(.*?)\s*$/;
    ($cmd, $_)= ($1, $2);
    @ARGV= parse_line($space,0,$_);
    @ARGV= map { /^(\d+)-(\d+)$/ ? $1..$2 : $_} @ARGV;
    $cmd= $cmd{$cmd} if defined($cmd{$cmd});
    if (defined($dispatch{$cmd})) {
        @msglist= &{$dispatch{$cmd}}(@msglist) if defined($dispatch{$cmd});
    } else {
        $cmd= join ' ',$cmd,@ARGV;
        system $cmd;
    }
} 

1;

=cut
## OBSOLETE unless readline and parseline are absent

sub cli {
    local $time;
    my ($line, $comm);
    local @msglist;
    $curmsg= 1 if ($#mailbox);
    $prompt= '"($time) $mbox: #$curmsg of " . $#mailbox . "> "';
    $_="";
    &setprompt;
    my $term= $term = new Term::ReadLine;
    while (defined ($_=$term->readline(eval $prompt))) {
        if (-s $mbox != $mailsize) {
            close MAIL;
            @mailbox=();
            loadmail();
            slurp();
        }
        foreach $line (split /;/) {
            @msglist=();
            foreach $comm (split /\|/, $line) {
                cli_proc($comm);
            }
        }
    } continue {
        &setprompt;
    }
}

sub cli_proc{
    ($_) = @_;
    if (/^\s*(\d+)\s*$/) {
# just a number, so print the message.
        $curmsg=$1;
        @ARGV=();
        &printmsg;
        return;
    }
    my $cmd;
# 'd3' is valid for 'delete 3'
    /^\s*([a-zA-z]+)\s*(.*)/;
    ($cmd, $_)= ($1, $2);
    @ARGV= split;
    print (map { if (/^(\d+)-(\d+)$/) {$1..$2;} } @ARGV), "\n";
    $cmd= $cmd{$cmd} if defined($cmd{$cmd});
    if (defined($dispatch{$cmd})) {
        @msglist= &{$dispatch{$cmd}}(@msglist) if defined($dispatch{$cmd});
    } else {
        $cmd= join ' ',$cmd,@ARGV;
        system $cmd;
    }
} 

1;
=cut
