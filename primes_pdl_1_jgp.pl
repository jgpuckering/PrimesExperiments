#!/usr/bin/env perl
package PrimeSieve;
use v5.12;
use strict;
use warnings;
use PDL;
use PDL::NiceSlice;

my %primes_lower_than = (
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
    # die "Expect a positive power of ten" unless (0+$sieve_size) =~ /^10+$/;
    my $bits=zeroes(byte, $sieve_size+1);
    my $q=sqrt($sieve_size);
    $bits(0:1).=1; # 0 and 1 are not prime
    return bless {
        sieve_size => $sieve_size,
        bits       => $bits,
        q          => $q,
        even       => 0,
        ran        => 0
    }, $class;
}

sub run_sieve {
    my $self = shift;
    return if $self->{ran};
    my $q      = $self->{q};
    my $bits   = $self->{bits};
    my $one=pdl(byte, 1);
    for(my $factor=3; $factor<=$q; $factor+=2) {
        $bits($factor*$factor:-1:2*$factor).=$one unless $bits(($factor));
    }
    $self->{ran}=1;
}

sub print_results {
    my ( $self, $show_primes, $duration, $passes ) = @_;

    my @primes;
    my $count;
    
    if ($show_primes) {
        @primes = $self->get_primes();
        $count = @primes;        
        printf "%s\n", join ',', @primes;
    } else {
        $count = $self->count_primes();
    }

    my $f = $self->validate_results($count);
    printf "Luis_Mochán_(wlmb)_Perl/PDL;%d;%f;%d;algorithm=base,faithful=%s,bits=8\n", $passes, $duration, 1, $f;
    printf {*STDERR} "Passes: %d, Time: %f, Avg: %f, Limit: %d, Count: %d, Valid: %s\n",
      $passes, $duration, $duration / $passes,
      $self->{sieve_size}, $count, $f;
}

sub deal_with_even {
    my $self = shift;
    my $bits=$self->{bits};
    $bits(2*2:-1:2).=1 unless $self->{even};
    $self->{even}=1;
}

sub get_primes {
    my $self = shift;
    $self->deal_with_even;
    my $bits=$self->{bits};
    # $bits->long->xvals->where(!$bits);
    $bits->long->xvals->where(!$bits)->list;
}

sub count_primes {
    my $self = shift;
    $self->deal_with_even;
    my $bits=$self->{bits};
    (!$bits)->sumover;
}

sub validate_results {
    my ($self, $count) = @_;

    my $f
        = $primes_lower_than{$self->{sieve_size}}
        ? $primes_lower_than{$self->{sieve_size}} == $count ? 'yes' : 'no'
        : 'unknown';
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
