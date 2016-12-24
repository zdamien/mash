sub slurp {
#sucks up an entire mailbox.  @mailbox is an array of hashrefs.  The
#hash has Header -- an array ref leading to the header lines -- Body 
# -- the same thing for the body lines -- and various
#interesting fields for convenience.
# $mailbox[0] is a dummy; messages start at 1.

    my $messnum=0;
    my $header=0; 
    if (!defined MAIL or !-e $mbox) {return 0}
    while (<MAIL>) {
        if (/^From / && $mailbox[$messnum]{'Content-length:'} <=0) {
            $mailbox[$messnum]{'Lines'}=$line;
            $header=1; $line=0; $messnum++;
            $mailbox[$messnum]{Header}[$line]= $_;
            $mailbox[$messnum]{'From '}= $_;
            $line++;
            next;
        }
        if (/^\s*$/ and $header) {
            $header=0; $line=0; 
            $mailbox[$messnum]{'Status:'}="N" 
                if !defined $mailbox[$messnum]{'Status:'};
            next;
        }
        if ($header) {
        $mailbox[$messnum]{Header}[$line]= $_;
            if (/(^From:)|(^Subject:)|(^Date:)|(^To:)|(^Cc:)|(^Reply-To:)|(^Message-id:)|(^Status:)|(^Content-Length:)/i) {
                $field=$+;  /$field\s+(.*)/; 
                $field= ucfirst lc $field;
                $mailbox[$messnum]{$field}=$1;
                if ($field =~ /^Date/) {
                   $mailbox[$messnum]{Time}=datetotime($mailbox[$messnum]{'Date:'}); 
                }
            }
            $line++;
            next;
        }
#we're in the body; chug away
        $mailbox[$messnum]{Body}[$line++]=$_;
        $mailbox[$messnum]{'Content-length:'}-=length $_;
    }
#we've run off the end; set last # of lines
    $mailbox[$messnum]{Lines}=$line;

    ($mailtime)= (stat MAIL)[9];
}

sub sip {
}

use Date::Parse;

sub datetotime {
goto DATE;
    my ($wday, $mday, $mon, $year, $time, $zone)= split /\s+/, $_[0];
    my %week= (Sun => 0, Mon=>1, Tue=>2, Wed=>3, Thu=>4, Fri=>5, Sat=>6);
    chop $wday;
    $wday= $week{$wday};
    my %months= 
        (Jan=>0, Feb=>1, Mar=>2, Apr=>3, May=>4, Jun=>5, Jul=>6, Aug=>7,
         Sep=>8, Oct=>9, Nov=>10, Dec=>11);
    $mon= $months{$mon};
    $year-= 1900;
    ($hour, $min, $sec)= split /:/, $time;
DATE:  my $datez= $_[0];
    my ($sec,$min,$hour,$day,$mon,$year,$zone) = strptime($_[0]);
    my $t= str2time($datez);
    return $t;
    use Time::Local;
    return Time::Local::timegm($sec, $min, $hour, $mday, $mon, $year) - ($hour * 36);
    #time zone mod; $hour is '700' hours, so divide by hundred, then mult.
    # by 3600 for seconds.
}

1;
