#!/usr/bin/perl

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
        my ( $class, $sieve_size ) = @_;

        # Each byte of $bytes represents on odd number in our virtual
        # bit map; i.e. positions 1,3,5...size/2
        # This is so we can ignore even numbers, which except for 2
        # (a special case) are all non-prime.
        # We start by initializing this bytemap to 1's to indicate
        # all positions are non-prime; then we'll set primes to 0
        my $bytes = '1' x int(($sieve_size+1)/2);

        bless {
            sieve_size  => $sieve_size,
            bytes       => $bytes,
            byteslen    => length $bytes,
            iloops      => 0,
            mloops      => 0,
        }, $class;
    }

    # Sieve of Erastothenes
    sub run_sieve {
        my ($self) = @_;

        my $bytes_ref = \$self->{bytes};
        my $byteslen  = $self->{byteslen};
        my $factor    = 1;
        my $q         = sqrt($self->{sieve_size})/2;

        while ( $factor <= $q ) {
            # $self->{iloops}++;
            $factor = index($$bytes_ref, '1', $factor);

            # If marking factor 3, you wouldn't mark 6 (it's a mult of 2)
            # so start with the 3rd instance of this factor's multiple.
            # We can then step by factor * 2 because every second one
            # is going to be even by definition.

            my $start = 2 * $factor * ($factor + 1);
            my $step = $factor * 2 + 1;
            last if $start > $byteslen;

            $self->set_rng_bitwise($start, $byteslen, $step, '0');
            # $self->{mloops} += set_rng_inline($$bytes_ref, $start, $byteslen, $step, '0');

            $factor += 1;
        }
    }

    sub set_rng_bitwise {
        my ($self, $from, $to, $step, $v) = @_;

        # In this algorithm we start with 1 in all bit positions and then
        # set factor multiples to zero.  After all passes are done, those
        # bitmap positions with 1 are the primes

        # To flip a position from 0 to 1 we'll use bitwise AND and a mask
        # of 0; where we want to leave the position alone, we'll use 1

        my $bytes_ref = \$self->{bytes};
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
        my ($self) = @_;

        my $bytes_ref = \$self->{bytes};
        my $byteslen  = $self->{byteslen};

        my $idx = 1;
        my @primes;

        # Since we auto-filter evens, we have to special case the number 2 which is prime
        push @primes, 2 if ($byteslen > 1);

        return @primes unless $byteslen > 2;

        while ($idx > 0) {
            push @primes, $idx * 2 + 1;
            $idx = index($$bytes_ref,'1', $idx + 1);
        }

        return @primes;
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

my $opt_size      = 1_000_000;
my $opt_passes    = 0;
my $opt_primes    = 0;
my $opt_nostats   = 0;
my $opt_duration  = 5;

GetOptions(
    'size=i',    => \$opt_size,         # sieve size
    'passes=i'   => \$opt_passes,       # by passes not duration
    'primes'     => \$opt_primes,       # show primes
    'nostats'    => \$opt_nostats,      # don't show stats
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
        $sieve = PrimeSieve->new($opt_size);
        $sieve->run_sieve();
        $mloops += $sieve->{mloops};
        $iloops += $sieve->{iloops};
        $passes++;
    }
} else {
    while (duration($start_time) < $opt_duration ) {
        $sieve = PrimeSieve->new($opt_size);
        $sieve->run_sieve();
        $mloops += $sieve->{mloops};
        $iloops += $sieve->{iloops};
        $passes++;
    }
}

$sieve->print_results( $opt_primes, duration($start_time), $passes )
    unless $opt_nostats;

# printf("interpreter loops = $iloops  machine loops = $mloops\n");

__END__
