#!/usr/bin/perl

use strict;
use warnings;


package PrimeSieve {
    use Bit::Vector;
    use feature 'say';

    our $bitstring = '0' x 30;

    my $TRACE = 0;

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

        # create bitmask where even numbers are marked non-prime
        my $chars = '10' x int($sieve_size/2);
        substr($chars, 1, 1) = '1';  # 1 is non-prime
        substr($chars, 2, 1) = '0';  # 2 is prime

        bless {
            sieve_size => $sieve_size,
            chars      => \$chars,
        }, $class;
    }

    sub chars {
        my $self = shift;
        return ${ $self->{chars} };
    }

    sub size {
        my $self = shift;
        return $self->{sieve_size};
    }

    sub run_sieve {
        my $self   = shift;

        my $size   = $self->size;
        my $chars  = $self->{chars};
        my $q      = sqrt $size;
        my $factor = 1;

        while ( $factor <= $q ) {
            $factor += 2;
            # $$chars dereferences $self->{chars}, which contains a scalar reference
            main::set_bit_range( $$chars, $factor*$factor, $size, $factor*2);
        }
    }

    sub get_primes {
        my $self = shift;

        my $chars  = $self->{chars};
        my @primes = (2);
        foreach (my $ii = 3; $ii < $self->{sieve_size}; $ii += 2) {
            push @primes, $ii if not substr($self->chars, $ii, 1);
        }
        return @primes;
    }

    sub print_results {
        my ( $self, $show_results, $duration, $passes ) = @_;
        my @primes = $self->get_primes();
        my $count = @primes;

        printf "%s\n", join ',', @primes if $show_results;

        my $f = $self->validate_results($count);
        printf "jgpuckering/inlineC;%d;%f;%d;algorithm=base,faithful=%s,bits=8\n", $passes, $duration, 1, $f;
        printf {*STDERR} "Passes: %d, Time: %.2f, Avg: %f, Passes/sec: %.1f, Limit: %d, Count: %d, Valid: %s\n",
          $passes, $duration, $duration / $passes, $passes / $duration,
            $self->{sieve_size}, $count, $f;
    }

    sub validate_results {
        my ($self, $count) = @_;

        my $f
            = $DICT{$self->size}
            ? $DICT{$self->size} == $count ? 'yes' : 'no'
            : 'unknown';
    }
};


package main;

use Getopt::Long;
use Time::HiRes 'time';

use Inline C => <<~'__C__';
    void set_bit_range(char *str, int start, int stop, int step) {
        int i = 0;
        char c;

        for (i=start; i<stop; i+=step) {
            str[i] = '1';
        }
    }
__C__

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
