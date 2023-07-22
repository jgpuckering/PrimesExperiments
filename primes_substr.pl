#!/usr/bin/env perl

use strict;
use warnings;

package PrimeSieve {

    my %DICT = (
        10          => 4,
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

        # initialize bit string so that even positions are marked 1
        my $bits = '0' . '01' x int($sieve_size/2);
        substr($bits,2,1,0);

        bless {
            sieve_size => $sieve_size,
            bits       => $bits,
        }, $class;
    }

    sub run_sieve {
        my $self   = shift;
        my $size   = $self->{sieve_size};
        my $bits   = \$self->{bits};
        my $q      = sqrt $size;
        my $factor = 1;

        # printf "bits %s\n", $$bits;

        while ( $factor <= $q ) {
            # factor will be 3, 5, 7 ... $q
            $factor += 2;

            if ( substr($$bits, $factor,1) ) {
                my $ii = index($$bits, '0', $factor);
                $factor = $ii if $ii > 0;
            }

            my $start = $factor * $factor;
            my $step = $factor * 2;

            for ( my $i = $start; $i < $size; $i += $step ) {
                substr($$bits, $i, 1, '1');
            }
            #printf "bits %s\n", $$bits;
        }
    }

    sub primes {
        my $self = shift;
        my $bits = \$self->{bits};

        # First, construct a list consisting of 2 and then all odd numbers
        # from 3 to the sieve size.  Then select those entries that
        # have a corresponding bit marked 0 in the bit map.
        # The attempted performance improvement here is to use grep
        # to avoid the overhead of an interpreter loop (e.g. while or for)
        # though profiling indicates it's not a win.

        grep !substr($$bits,$_,1), (2, grep $_ % 2, 3..$self->{sieve_size} );
    }

    sub print_results {
        my ( $self, $show_primes, $duration, $passes ) = @_;
        my @primes = $self->get_primes();
        my $count = @primes;
        my $f = $self->validate_results($count);
        printf "%s\n", join ',', @primes if $show_primes;
        printf "jgpuckering/$0;%d;%f;%d;algorithm=base,faithful=%s,bits=8\n", $passes, $duration, 1, $f;
        printf {*STDERR} "Passes: %d, Time: %f, Avg: %f, Limit: %d, Count: %d, Valid: %s\n",
          $passes, $duration, $duration / $passes,
          $self->{sieve_size}, $count, $f;
    }

    sub get_primes {
        my $self = shift;

        my @primes = (2);
        foreach (my $ii = 3; $ii < $self->{sieve_size}; $ii += 2) {
            push @primes, $ii if not substr($self->{bits}, $ii, 1);
        }
        return @primes;
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

my $passes   = 0;
my $duration = 0;
my $sieve;
my $start_time = time;

sub duration { time() - $start_time }

if ($opt_passes) {
    $sieve = PrimeSieve->new($opt_size);
    for ( my $i = 0; $i < $opt_passes; $i++ ) {
        $sieve->run_sieve();
        $passes++;
    }
} else {
    while (duration() < $opt_duration ) {
        $sieve = PrimeSieve->new($opt_size);
        $sieve->run_sieve();
        $passes++;
    }
}

$sieve->print_results( $opt_primes, duration(), $passes )
    unless $opt_nostats;

__END__
