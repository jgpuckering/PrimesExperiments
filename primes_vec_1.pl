#!/usr/bin//perl

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

        vec(my $bv, $sieve_size, 1) = 0;
        vec($bv, 1, 1) = 1;     # 1 is not prime

        return bless {
            sieve_size => $sieve_size,
            bits       => $bv,
        }, $class;
    }

    sub set_rng {
        my ($self, $from, $to, $step) = @_;

        for (my $i = $from; $i <= $to; $i += $step) {
            vec($self->{bits}, $i, 1) = 1;
        }
    }

    sub run_sieve {
        my $self = shift;

        my $size = $self->{sieve_size};
        my $q = sqrt $size;

        for (my $factor = 3; $factor <= $q; $factor += 2) {
            $self->set_rng( $factor*$factor, $size, 2*$factor )
                unless vec( $self->{bits}, $factor, 1 );
        }
    }

    sub print_results {
        my ( $self, $show_primes, $duration, $passes ) = @_;
        my @primes = $self->get_primes();
        my $count = @primes;
        printf "%s\n", join ',', @primes if $show_primes;
        printf "jgpuckering/$0;%d;%f;%d;algorithm=base,faithful=yes,bits=8\n", $passes, $duration, 1;
        printf {*STDERR} "Passes: %d, Time: %f, Avg: %f, Limit: %d, Count: %d, Valid: %s\n",
          $passes, $duration, $duration / $passes,
          $self->{sieve_size}, $count, $self->validate_results($count);
    }

    sub get_primes {
        my $self = shift;
        my @primes = (2);
        foreach (my $ii = 3; $ii < $self->{sieve_size}; $ii += 2) {
            push @primes, $ii if not vec($self->{bits}, $ii, 1);
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
}

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
