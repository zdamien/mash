use strict; 

use vars qw($show_del);

%dispatch= (
    'print' => \&printmsg,
    'next' => sub {&nextmsg; &printmsg;},
    "" => \&printmsg,
    'prev' => sub {&prevmsg; &printmsg;},
    'delete' => sub {&delmsg; &nextmsg;},
    'dp' => sub {&delmsg; &nextmsg; &printmsg;},
    'undelete' => \&undelmsg,
    'exit' => sub {exit 0;},
    'quit' => \&quit,
    'saveopts' => \&saveopts,
    'replysender' => \&reply,
    'reply' => \&reply,
    'mail' => \&mail,
    'save' => \&save,
    'update' => \&savemail,
    'folder' => \&folder,
    'headers' => sub {$show_del=0; &headers;},
    'H' => sub {$show_del=1; &headers;},
    'set' => \&set,
    'unset' => \&unset,
    'alias' => \&alias,
    'unalias' => \&unalias,
    'cmd' => \&cmd,
    'uncmd' => \&uncmd,
    'sort' => \&sortmail,
    'pick' => \&pick,
    'help' => \&help,
    'forge' => \&forge,
    'unforge' => \&unforge,
);

sub lockmail {
#locks a file.  Currently by making a .lockfile.
    my $file= shift (@_);
    my $timer = 0;
    while (-e "$file.lock") {
        sleep 1; 
        $timer++; 
        warn "$mbox still locked" and return 0 if $timer == 10;
        #loop until lockfile goes away
    }
    open (LOCK,">$file.lock");
    close LOCK;
    return 1;
}

sub unlock {
#unlocks files.  Removes the .lock file.
    my $file= shift (@_);
    unlink "$file.lock";
}

sub nextmsg {
    $curmsg %= $#mailbox;
    my $mailsize= $#mailbox;
    do {$curmsg++} until !$mailbox[$curmsg]{Deleted};
    ($curmsg=1), $#mailbox-- if ($curmsg > $mailsize);  
    #all deleted; default to msg 1.
}

sub prevmsg {
    do {$curmsg--} until !$mailbox[$curmsg]{Deleted};
    $curmsg = $#mailbox if $curmsg==0;
}

sub printmsg {
    my ($msg, $message, @shown);
    push @_, @ARGV;
    if (scalar(@_)==0) {push @_, ($curmsg);}
    foreach $msg (@_) {
        if ($msg<1 or $msg>$#mailbox) {
            print "Invalid message number: $msg\n";
            next;
        }
        if ($mailbox[$msg]{Deleted}) {
            print "Message $msg deleted; Type 'undelete $msg' to undelete\n";
            next;
        }
        $message= $mailbox[$msg];
#if you look at a long message, and quit before you reach the end,
#mash itself quits.
$SIG{PIPE}= 'IGNORE';
$SIG{CHLD}= 'IGNORE';
        open (PAGER,"|$pager") or warn "Couldn't open $pager";
        print PAGER "Message #$msg ($message->{Lines})\n";
        print PAGER $message->{'From '};
	foreach (qw( From: To: Subject: Date: Reply-to: Cc:)) {
	    print PAGER "$_ $message->{$_}\n" if defined $message->{$_};
	}
        print PAGER "\n";
        print PAGER @{$message->{Body}};
        close PAGER;
        $message->{'Status:'}= "R";
	push @shown, $msg;
$SIG{PIPE}= 'DEFAULT';
$SIG{CHLD}= 'DEFAULT';
    }
    $curmsg= @shown ? $shown[$#shown] : $curmsg;
    return @shown;
}

my (@includes, @To);
sub mail {
    my ($bcc, $cc, $subject, $forward, $include, $prefix);
    my $inc;
    
    GetOptions('b=s' => \$bcc, 'c=s' => \$cc, 'f' => \$forward, 'i' =>
	\$include, 's:s' => \$subject, "<>", \&msgparse);
    if ($include and !@includes) {push @includes, $curmsg;}
    $prefix = "> " unless defined ($forward);
    my ($fh, $tmpname) = tmpfile();
    print $fh <<EOH;
From: $from
To: @To
Subject: $subject
Cc: $cc
Bcc: $set{From}

EOH
    foreach $inc (@includes) {
        print $fh "On $mailbox[$inc]{Date} $mailbox[$inc]{'From:'} wrote:\n";
        my $line;
        foreach $line (@{$mailbox[$inc]{Body}}) {
            print $fh "$prefix$line";
        }
    }
    close $fh;
EDIT:    system("$editor $tmpname");
PROMPT:    print "send, continue editing, discard [s,c,d]? ";
    my $command= <STDIN>;
    chomp $command;
    goto EDIT if $command eq "c";
    goto MAIL_CLEANUP if $command eq "d";
    goto PROMPT if $command ne "s";
    my $error= system("$set{Sendmail} < $tmpname");
MAIL_CLEANUP:
    close $fh;
    unlink $tmpname;
    @To=(); @includes=();
}

sub msgparse {
    ($_)=@_;
    push (@includes, ($_)), next if /^\d+$/;
    push @To, (defined $aliases{$_}) ? $aliases{$_} : $_;
}

sub reply {
    my $To= $mailbox[$curmsg]{'Reply-To:'} || $mailbox[$curmsg]{'From:'};
    my $Subject= "Re: $mailbox[$curmsg]{'Subject:'}";
    $Subject=~ s/(\s*R[eE]:)+/Re:/;

    push @ARGV, ("-s",$Subject,$To);
    mail();
}

sub delmsg {
    push @_, @ARGV;
    my @deleted;
    if (scalar(@_)==0) {$mailbox[$curmsg]{Deleted}=1; 
	push @deleted, $curmsg;}
    else {
        my $msg;
        while (@_) {
            $msg= shift @_;
            $mailbox[$msg]{Deleted}=1;
	    push @deleted, $msg;
        }
    }
    return @deleted;
}

sub undelmsg {
    push @_, @ARGV;
    my @undeleted;
    if (scalar(@_)==0) {$mailbox[$curmsg]{Deleted}=0; 
	push @undeleted, $curmsg;}
    else {
        my $msg;
        while (@_) {
            $msg= shift @_;
            delete $mailbox[$msg]{Deleted};
	    push @undeleted, $msg;
        }
    }
    return @undeleted;
}

sub save {
    warn "No mailbox specified" and return () if $#ARGV==-1;
    my $saveto= pop @ARGV;
    $saveto=~ s:^+:$set{MAILDIR}/:;
    push @_, @ARGV;
    push @_, $curmsg if scalar(@_)==0;
    lockmail($saveto) or warn "Couldn't lock $saveto" and return ();
    open SAVETO, ">>$saveto" or warn "Couldn't open $saveto" and return ();
    @_= sort {$a <=> $b} @_;
    my $msg;
    my @savelist= @_;
    while (@_) {
        $msg= shift @_;
        print SAVETO @{$mailbox[$msg]{Header}},"\n",@{$mailbox[$msg]{Body}};
    }
    close SAVETO;
    unlock($saveto);
    return @savelist;
}

sub savemail {
    my ($fh, $tmpname) = tmpfile();
    lockmail($mbox) or warn "Can't save" and return;
#return;
    for (my $i=1; $i<=$#mailbox; $i++) {
        next if ($mailbox[$i]{Deleted});
        print $fh grep {!/^Status:/} @{$mailbox[$i]{Header}};
        $mailbox[$i]{'Status:'}=~ s/N/O/;
        print $fh "Status: $mailbox[$i]{'Status:'}\n";
        print $fh "\n";
        print $fh @{$mailbox[$i]{Body}};
    }
    close $fh;
    utime $mailtime, $mailtime, $tmpname; 
    `cmp -s $tmpname $mbox`;
    (rename $tmpname, $mbox or print "Can't move $tmpname to $mbox ($!)\n")
	if $?>>8;
    unlock($mbox);
    unlink $tmpname;
    unlink $mbox if -z $mbox;
}

sub headers {
    push @_, @ARGV;
    @_= 1..$#mailbox if !@_;
    my @msglist;
    return () if $_[0]== -1;
    my ($cur, $i, $status, $mailfrom, $month, $day, $time, $lines, $subject);
format HEADERS =
@@>> @|| @<<<<<<<<<<<<<<<<<<<<  @|| @> @>>>> (@<<<li) @<<<<<<<<<<<<<<<<<<<<<<<<
$cur, $i, $status, $mailfrom, $month, $day, $time, $lines, $subject;
.
    use FileHandle;
$SIG{PIPE}= 'IGNORE';
$SIG{CHLD}= 'IGNORE';
    open (PAGER,"|$pager") or warn "Couldn't open $pager";
    format_name PAGER "HEADERS";
    $= = 25;
    foreach $i (@_) { 
        next if (!$show_del && $mailbox[$i]{Deleted});
        if ($mailbox[$i]{'From:'} =~ /$set{From}/)
            {$mailfrom= "TO: $mailbox[$i]{'To:'}";}
        else {$mailfrom= $mailbox[$i]{'From:'};}
        $mailfrom= getfrom($mailfrom);
        $mailbox[$i]{'Date:'} =~ /(?:\w*, +)?(\d*) +(\w*) +(\d*) +(.*)/;
        $month= $2; $day=$1; $time=$4;
        $subject= $mailbox[$i]{'Subject:'};
        $lines=$mailbox[$i]{'Lines'};
        $status= $mailbox[$i]{Deleted} ? 'D' : $mailbox[$i]{'Status:'};
        $status=~ s/R//; 
        $cur= $i==$curmsg ? ">" : "";
	push @msglist, $i;
        write PAGER;
    }
#    format_name STDOUT "STDOUT";
    close PAGER;
$SIG{PIPE}= 'DEFAULT';
$SIG{CHLD}= 'DEFAULT';
    return @msglist;
}

sub getname {
    ($_)= @_;
    return $1 if /\((.*)\)/;
    return $+ if /(.*)<.*>(.*)/;
    return $_;
}

sub getfrom {
    ($_)= @_;
    return $+ if /<(.*)>/;
    return $1 if /(.*)\(.*\)(.*)/;
    return $_;
}

sub folder {
    my ($n);
    GetOptions('n' => \$n);
    savemail() unless $n;
    $#mailbox= -1;
    close MAIL;
    $mbox= shift @ARGV;
    $mbox =~ s:^+:$set{MAILDIR}/:;
    loadmail();
    slurp();
}
    
sub tmpfile {
    local *TEMP;
    my $tmp = int(rand 10000);
    while (-e ".tmp$tmp") {$tmp= int(rand 10000);} #find free tempfile
    $tmp= "$wdir/.tmp$tmp";
    open(TEMP,">$tmp");
    return (*TEMP, $tmp);
}

sub quit {
    savemail();
    saveopts();
    exit 0;
}

sub saveopts {
    my ($vars, $aliases, $cmds);
    foreach my $set (sort keys %set) {
        $vars .= "\t\'$set\' => \'$set{$set}\',\n"
    }
    foreach my $alias (sort keys %aliases) {
        $aliases .= "\t\'$alias\' => \'$aliases{$alias}\',\n"
    }
    foreach my $cmd (sort keys %cmd) {
        $cmds .= "\t\'$cmd\' => \'$cmd{$cmd}\',\n"
    }
    open CONF, ">/home/damien/.mashrc" or die "($!)\n";
    print CONF <<EOO;
%set=(
$vars
);
%aliases=(
$aliases
);
%cmd=(
$cmds
);
EOO
}

sub set {
    my ($var, $value) = @ARGV;
    if (!@ARGV) {
        foreach $var (sort keys %set) {
            print "$var\t$set{$var}\n"
        } 
    } else {
        $set{$var}= $value;
    }
}

sub unset {
    while (@ARGV) {
        delete $set{$ARGV[0]} if defined($set{$ARGV[0]});
        shift @ARGV;
    }
}
    
sub alias {
    my ($alias, $address) = @ARGV;
    if (!@ARGV) {
        foreach $alias (sort keys %aliases) {
            print "$alias\t$aliases{$alias}\n"
        } 
    } else {
        $aliases{$alias}= $address;
    }
}

sub unalias {
    while (@ARGV) {
        delete $aliases{$ARGV[0]} if defined($aliases{$ARGV[0]});
        shift @ARGV;
    }
}

sub cmd {
    my ($short, $expansion) = @ARGV;
    if (!@ARGV) {
        foreach my $cmd (sort keys %cmd) {
            print "$cmd\t$cmd{$cmd}\n"
        } 
    } else {
        $cmd{$short}= $expansion;
    }
}

sub uncmd {
    while (@ARGV) {
        delete $cmd{$ARGV[0]} if defined($cmd{$ARGV[0]});
        shift @ARGV;
    }
}

sub sortmail {
    my ($nocase, $rev, $bydate, $bysub);
    push @ARGV, $set{Sort} unless @ARGV;
    $_= join '', @ARGV;
    s/\-//g;
    s/(.)/$1:/g;
    s/r:/r/g;
    my @order=split /:/;
    my $sortm= "";
    my $nextcomp;
    foreach $_ (@order) {
        SWITCH: {
            /d/ and $nextcomp = '$c->{Time} <=> $d->{Time} or ' and next;
            /f/ and $nextcomp = q|$c->{'From:'} cmp $d->{'From:'} or | and next;
            /t/ and $nextcomp = q|$c->{'To:'} cmp $d->{'To:'} or | and next;
            /s/ and $nextcomp = q|subjcomp($c->{'Subject:'}, $d->{'Subject:'}) or | and next;
            /S/ and $nextcomp = q(defined $c->{Deleted} <=> defined $d->{Deleted} || $c->{'Status:'} cmp $d->{'Status:'} or ) and next;
        } continue {
            if (/r/) {
                $nextcomp =~ s/\$c/\$b/g;
                $nextcomp =~ s/\$d/\$a/g;
            } else {
                $nextcomp =~ s/\$c/\$a/g;
                $nextcomp =~ s/\$d/\$b/g;
            }
            $sortm .= $nextcomp;
        }
    }
    $sortm =~ s/(.*) or $/$1/;

    sub subjcomp {
        my ($c, $d)= @_;
        $c=~ s/\s*R[eE]:\s(.*)/$1/;
        $d=~ s/\s*R[eE]:\s(.*)/$1/;
        return $c cmp $d;
    }

    @mailbox[1..$#mailbox]= sort {eval $sortm} @mailbox[1..$#mailbox];
}

sub pick {
    my ($byto, $byfrom);
    GetOptions('t=s'=>\$byto, 'f=s'=>\$byfrom);
    my @j;
    if ($byto) {
        @j= grep {$mailbox[$_]{'To:'} =~ /$byto/} 1..$#mailbox;
        return @j ? @j : (-1);
    } elsif ($byfrom)  {
        @j= (grep {$mailbox[$_]{'From:'} =~ /$byfrom/} 1..$#mailbox);
        return @j ? @j : (-1);
    } else {
        @j= grep {
            my $msg= $_;
            grep {/$ARGV[0]/} (@{$mailbox[$msg]{Header}},@{$mailbox[$msg]{Body}});
        } 1..$#mailbox;
        return @j ? @j : (-1);
   }
}


sub help {
    my @commands;
format HELP =
@<<<<<<<<<<<<<<@<<<<<<<<<<<<<<@<<<<<<<<<<<<<<@<<<<<<<<<<<<<<@<<<<<<<<<<<<<<
@commands;
.
    @commands= sort keys %dispatch;
    use FileHandle;
    format_name STDOUT "HELP";
    while (@commands) {
        write;
        splice @commands, 0, 5;
    }
    format_name STDOUT "STDOUT";
}

sub forge {
    $from= @ARGV ? $ARGV[0] : $set{Forge};
}

sub unforge {
    $from= $set{From};
}

1;

