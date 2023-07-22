use strict;
use warnings;

use feature 'say';
use Time::HiRes 'time';

my $SieveSize = 1_000_000;
my $Iter = 200;
# my $SieveSize = 60;
# my $Iter = 1;

my $PrintPrimes = 0;
my $UseInline   = 1;

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

for (1..$Iter) {
    $bytes = allocate($SieveSize);
    inspect($bytes);
    set_to_zero($bytes);
    sieve(\$bytes,$SieveSize);
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
    my ($bytes_ref, $size) = @_;

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

        if ($UseInline) {
            set_rng_inline($$bytes_ref, $start, $byteslen, $step, '0');            
        } else {
            set_rng($bytes_ref, $start, $byteslen, $step, '0');
        }

        $factor += 1;
    }
    $stats{'sieve'} += time() - $start_time;

    if ($PrintPrimes) {
        my @primes = get_primes($bytes);
        printf "Found %d primes\n", scalar @primes;
        printf "%s\n", join ', ', @primes;
    }
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
        printf "%-15s %4d %8d %f\n", $label, $Iter, $byteslen, $stats{$label};
    }
}
