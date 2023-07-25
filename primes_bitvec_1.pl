#!/usr/bin/perl

use strict;
use warnings;

package PrimeSieve {
    use Bit::Vector;

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
            bits       => Bit::Vector->new($sieve_size),
        }, $class;
    }

    sub bits {
        my $self = shift;
        return $self->{bits};
    }

    sub size {
        my $self = shift;
        return $self->{sieve_size};
    }

    sub run_sieve {
        my $self   = shift;
        my $size   = $self->{sieve_size};

        $self->{bits}->Primes;
    }

    sub print_results {
        my ( $self, $show_results, $duration, $passes ) = @_;

        my @primes = $self->get_primes();
        my $count = @primes;

        printf "%s\n", join ',', @primes
            if $show_results;

        my $f = $self->validate_results($count);
        printf "jgpuckering/$0;%d;%f;%d;algorithm=base,faithful=%s,bits=1\n", $passes, $duration, 1, $f;
        printf {*STDERR} "Passes: %d, Time: %.2f, Avg: %f, Passes/sec: %.1f, Limit: %d, Count: %d, Valid: %s\n",
          $passes, $duration, $duration / $passes, $passes / $duration,
          $self->size, $count, $f;
    }

    sub get_primes {
        my $self = shift;
        my $primes = $self->bits->to_Enum();
        my @primes = split /,/, $primes;
        return @primes;
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

use Time::HiRes 'time';
use Getopt::Long;

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

my $passes = 0;
my $duration=0;
my $sieve;
my $start_time = time;

if ($opt_passes) {
    $sieve = PrimeSieve->new($opt_size);
    for ( my $i = 0; $i < $opt_passes; $i++ ) {
        $sieve->run_sieve();
        $passes++;
    }
    $duration = time - $start_time;
} else {
    while ($duration < $opt_duration ) {
        $sieve = PrimeSieve->new($opt_size);
        $sieve->run_sieve();
        $passes++;
        $duration = time - $start_time;
    }
}

$sieve->print_results( $opt_primes, $duration, $passes )
    unless $opt_nostats;

__END__
