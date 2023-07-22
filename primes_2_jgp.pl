#!/usr/bin/perl

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
        bless {
            sieve_size => $sieve_size,
            bits       => 0 x $sieve_size,
        }, $class;
    }

    sub run_sieve {
        my $self   = shift;
        my $size   = $self->{sieve_size};
        my $bits   = \$self->{bits};
        my $q      = sqrt $size;
        my $factor = 1;
        while ( $factor <= $q ) {
            $factor += 2;
            $factor += 2 while $factor < $size and substr($$bits,$factor,1);
            my $repeat = 1  .  0 x (2*$factor-1);
            my $times = (length($$bits)-$factor**2)/2/$factor + 1;
            my $s = 0 x $factor**2  .  $repeat x $times;
            $$bits |= $s;
        }
    }

    sub get_primes {
        my $self = shift;
        my $bits = \ $self->{bits};
        grep !substr( $$bits, $_, 1 ),
            ( 2, grep $_ % 2, 3 .. $self->{sieve_size} );
    }

    sub print_results {
        my ( $self, $show_results, $duration, $passes ) = @_;

        my @primes = $self->get_primes();
        my $count = @primes;
        print join ',', @primes if $show_results;

        my $f = $self->validate_results($count);
        printf "kjetillll;%d;%f;%d;algorithm=base,faithful=%s,bits=8\n", $passes, $duration, 1, $f;
        printf {*STDERR} "Passes: %d, Time: %f, Avg: %f, Limit: %d, Count: %d, Valid: %s\n",
          $passes, $duration, $duration / $passes,
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
