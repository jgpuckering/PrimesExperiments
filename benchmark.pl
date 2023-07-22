use strict;
use warnings;

use feature 'say';

use Getopt::Long;
use Text::Abbrev        qw( abbrev );
use Time::HiRes 'time';

my %stats;
my $bytes;

use Inline C => <<~'__C__';
    int set_rng_inline(char *str, int start, int stop, int step, char *v) {
        int i;
        int cnt = 0;
        // printf("%d %s\n", start, str);
        for (i=start; i<stop; i+=step) {
            str[i] = v[0];
            cnt++;
        }
        return cnt;
    }
__C__

my $Opt_size      = 1_000_000;
my $Opt_passes    = 200;
my $Opt_primes    = 0;
my $Opt_algorithm = 'substr';   # or inline or bitwise

GetOptions(
    'size=i',      => \$Opt_size,         # sieve size
    'passes=i'     => \$Opt_passes,       # by passes not duration
    'primes'       => \$Opt_primes,       # show primes
    'algorithm=s'  => \$Opt_algorithm,    # choose the algorithm
);

my %alg = abbrev( qw( substr inline bitwise) );
my $algorithm = $alg{$Opt_algorithm};
die "*E* unrecognized algorithm\n" if not $algorithm;

my @primes;
for (1..$Opt_passes) {
    $bytes = allocate($Opt_size);
    inspect($bytes);
    set_to_zero($bytes);
    @primes = sieve(\$bytes,$Opt_size, $algorithm);
}

if ($Opt_primes) {
    printf "Found %d primes\n", scalar @primes;
    printf "%s\n", join ' ', @primes;
}


print_results($bytes);

######################################################################

sub allocate {
    my $size = shift;

    my $start_time = time();
    my $bytes = '1' x int(($size+1)/2);
    $stats{'allocate'} += time() - $start_time;
    return $bytes;
}

sub inspect {
    my ($bytes) = @_;

    my $byteslen = length $bytes;
    my $start_time = time();
    for (my $i = 0; $i < $byteslen; $i++) {
        if ( substr($bytes, $i, 1) ) {}
    }
    $stats{'inspect'} += time() - $start_time;
}

sub set_to_zero {
    my ($bytes) = @_;

    my $byteslen = length $bytes;
    my $start_time = time();
    for (my $i = 0; $i < $byteslen; $i++) {
        substr($bytes, $i, 1, '0');
    }
    $stats{'set to zero'} += time() - $start_time;
}

sub sieve {
    my ($bytes_ref, $size, $algorithm) = @_;

    # Sieve of Erastothenes
    my $start_time = time();

    my $byteslen = length $$bytes_ref;
    my $factor = 1;
    my $q = sqrt($size)/2;

    while ( $factor <= $q ) {
        $factor = index($$bytes_ref, '1', $factor);

        # If marking factor 3, you wouldn't mark 6 (it's a mult of 2)
        # so start with the 3rd instance of this factor's multiple.
        # We can then step by factor * 2 because every second one
        # is going to be even by definition.

        my $start = 2 * $factor * ($factor + 1);
        my $step = $factor * 2 + 1;
        last if $start > $byteslen;

        if ($algorithm =~ 'substr') {
            set_rng($bytes_ref, $start, $byteslen, $step, '0');
        }
        elsif ($algorithm =~ 'inline') {
            set_rng_inline($$bytes_ref, $start, $byteslen, $step, '0');
        }
        elsif ($algorithm =~ 'bitwise') {
            set_rng_bitwise($bytes_ref, $start, $byteslen, $step, '0');
        }
        else {
            die "*E* unrecognized algorithm\n";
        }

        $factor += 1;
    }
    $stats{'sieve_' . $algorithm} += time() - $start_time;

    return get_primes($bytes);
}

sub set_rng {
    my ($bytes_ref, $from, $to, $step, $v) = @_;

    my $cnt = 0;

    for (my $i = $from; $i < $to; $i += $step) {
        substr($$bytes_ref, $i, 1) = $v;
        $cnt++;
    }
    return $cnt;
}

sub set_rng_bitwise {
    my ($bytes_ref, $from, $to, $step, $v) = @_;

    # In this algorithm we start with 1 in all bit positions and then
    # set factor multiples to zero.  After all passes are done, those
    # bitmap positions with 1 are the primes

    # To flip a position from 0 to 1 we'll use bitwise AND and a mask
    # of 0; where we want to leave the position alone, we'll use 1

    my $span        = $to - $from + 1;
    my $times       = int($span / $step);
    my $remainder   = ($span % $step) - 1;
    my $cnt         = $step * $times;
    
    my $notv
        = $v eq '0' ? '1'
        : '0';

    my $step_mask = $v . $notv x ($step - 1);
    my $tail_mask = substr $step_mask, 0, $remainder;
    my $mask = $step_mask x $times . $tail_mask;
    substr($$bytes_ref, $from, $span) &= $mask;

    return $cnt;
}

sub get_primes {
    my $bytes = shift;

    my $size = length $bytes;
    my $idx = 1;
    my @primes;

    # Since we auto-filter evens, we have to special case the number 2 which is prime
    push @primes, 2 if ($size > 1);

    return @primes unless $size > 2;

    while ($idx > 0) {
        push @primes, $idx * 2 + 1;
        $idx = index($bytes,'1', $idx + 1);
    }

    return @primes;
}

sub print_results {
    my $size = shift;
    my $byteslen = length($size);
    printf "%-15s %4s %8s %s\n", qw(Task Iter Bytes Duration);
    foreach my $label (sort keys %stats) {
        printf "%-15s %4d %8d %f\n", $label, $Opt_passes, $byteslen, $stats{$label};
    }
}
