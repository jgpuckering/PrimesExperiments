#!/usr/bin/env perl

use strict;
use warnings;

package PrimeSieve {

    my %DICT = (
        10          => 4,
        60          => 17,
        100         => 25,
        1000        => 168,
        10000       => 1229,
        100000      => 9592,
        1000000     => 78498,
        10000000    => 664579,
        100000000   => 5761455,
        1000000000  => 50847534,
        10000000000 => 455052511,
    );

    sub new {
        my ( $class, $sieve_size, $use_inline ) = @_;

        # Each byte of $bytes represents on odd number in our virtual
        # bit map; i.e. positions 1,3,5...size/2
        # This is so we can ignore even numbers, which except for 2
        # (a special case) are all non-prime.
        # We start by initializing this bytemap to 1's to indicate
        # all positions are non-prime; then we'll set primes to 0
        my $bytes = '1' x int(($sieve_size+1)/2);

        bless {
            sieve_size => $sieve_size,
            bytes       => $bytes,
            iloops      => 0,
            mloops      => 0,
            inline      => $use_inline,
        }, $class;
    }

    sub run_sieve {
        my $self     = shift;

        my $inline   = $self->{inline};
        my $size     = $self->{sieve_size};
        my $bytes    = \$self->{bytes};
        my $byteslen = length $$bytes;
        my $mloops   = 0;
        my $iloops   = 0;
        my $q        = sqrt($size) / 2;
        my $factor   = 1;

        #printf "bytes %s\n", $$bytes;

        #                 sqrt(60)->|
        # pos    0 1 2 3|4  5  6  7 |  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29
        # factor 1 3 5 7|9 11 13 15 | 17 19 21 23 25 27 29 31 33 35 37 39 41 43 45 47 49 51 53 55 57 59
        #        1 1 1 1|1  1  1  1 |  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  0  1  1  0
        #               q

        while ( $factor <= $q ) {
            # factor will be 3, 5, 7 ... $q
            $factor = index($$bytes, '1', $factor);

            # If marking factor 3, you wouldn't mark 6 (it's a mult of 2)
            # so start with the 3rd instance of this factor's multiple.
            # We can then step by factor * 2 because every second one
            # is going to be even by definition.

            my $start = 2 * $factor * ($factor + 1);
            my $step = $factor * 2 + 1;

            if ($inline) {
                $self->{mloops} += main::set_rng_inline($$bytes, $start, $byteslen, $step, '0');
            } else {
                $self->{iloops} += $self->set_rng($start, $byteslen, $step, '0');
            }
            $self->{iloops}++;  # count this loop too

            $factor++;
            # printf "bytes %s\n", $$bytes;
        }
    }

    sub set_rng {
        my ($self, $from, $to, $step, $v) = @_;

        my $bytes = \$self->{bytes};
        my $cnt = 0;

        for (my $i = $from; $i <= $to; $i += $step) {
            # print "offset = $i byteslen = $to step = $step \n";
            substr($$bytes, $i, 1) = $v;
            $cnt++;
        }
        return $cnt;
    }

    sub get_primes {
        my $self = shift;
        my $bytes = \$self->{bytes};
        my $size  = $self->{sieve_size};

        my $idx = 1;
        my @primes;

        # Since we auto-filter evens, we have to special case the number 2 which is prime
        push @primes, 2 if ($size > 1);

        return @primes unless $size > 2;

        while ($idx > 0) {
            push @primes, $idx * 2 + 1;
            $idx = index($$bytes,'1', $idx + 1);
        }

        return @primes;
        # First, construct a list consisting of 2 and then all odd numbers
        # from 3 to the sieve size.  Then select those entries that
        # have a corresponding bit marked 0 in the bit map.
        # The attempted performance improvement here is to use grep
        # to avoid the overhead of an interpreter loop (e.g. while or for)
        # though profiling indicates it's not a win.

        # grep !substr($$bytes,$_,1), (2, grep $_ % 2, 3..$self->{sieve_size} );
    }

    sub print_results {
        my ( $self, $show_primes, $duration, $passes ) = @_;
        my @primes = $self->get_primes();
        my $count = @primes;
        my $f = $self->validate_results($count);
        printf "%s\n", join ',', @primes if $show_primes;
        my $script = (split /\\/, $0)[-1];    # get script name sans path
        printf "jgpuckering/$script;%d;%f;%d;algorithm=base,faithful=%s,bits=8\n", $passes, $duration, 1, $f;
        printf {*STDERR} "Passes: %d, Time: %.2f, Avg: %f, Passes/sec: %.1f, Limit: %d, Count: %d, Valid: %s\n",
          $passes, $duration, $duration / $passes, $passes / $duration, 
          $self->{sieve_size}, $count, $f;
    }

    sub validate_results {
        my ($self, $count) = @_;

        my $f
            = $DICT{$self->{sieve_size}}
            ? $DICT{$self->{sieve_size}} == $count ? 'yes' : 'no'
            : 'unknown';
    }
};

package main;

use Getopt::Long;
use Time::HiRes 'time';

use Inline C => <<~'__C__';
    int set_rng_inline(char *str, int start, int stop, int step, char *v) {
        int i;
        int cnt = 0;

        for (i=start; i<stop; i+=step) {
            str[i] = v[0];
            cnt++;
        }
        return cnt;
    }
__C__

my $opt_size      = 1_000_000;
my $opt_passes    = 0;
my $opt_primes    = 0;
my $opt_nostats   = 0;
my $opt_duration  = 5;
my $opt_inline    = 0;

GetOptions(
    'size=i',    => \$opt_size,         # sieve size
    'passes=i'   => \$opt_passes,       # by passes not duration
    'primes'     => \$opt_primes,       # show primes
    'nostats'    => \$opt_nostats,      # don't show stats
    'inline'     => \$opt_inline,       # use inline set_rng
);

my $mloops   = 0;
my $iloops   = 0;
my $passes   = 0;
my $duration = 0;
my $sieve;

sub duration {
    my $start_time = shift;
    time() - $start_time;
}

my $start_time = time;

if ($opt_passes) {
    for ( my $i = 0; $i < $opt_passes; $i++ ) {
        $sieve = PrimeSieve->new($opt_size, $opt_inline);
        $sieve->run_sieve();
        $mloops += $sieve->{mloops};
        $iloops += $sieve->{iloops};
        $passes++;
    }
} else {
    while (duration($start_time) < $opt_duration ) {
        $sieve = PrimeSieve->new($opt_size, $opt_inline);
        $sieve->run_sieve();
        $mloops += $sieve->{mloops};
        $iloops += $sieve->{iloops};
        $passes++;
    }
}

$sieve->print_results( $opt_primes, duration($start_time), $passes )
    unless $opt_nostats;

my $rng_sub = $opt_inline ? '' : '';
printf("interpreter loops = $iloops  machine loops = $mloops\n");

__END__
