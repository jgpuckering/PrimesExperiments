#!/usr/bin/perl

use strict;
use warnings;

package PrimeSieve {
    use Bit::Vector;
    use feature 'say';

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
        my $nonprimes = '01'x($sieve_size/2);
        my $bits = Bit::Vector->new_Bin($sieve_size, $nonprimes);
        $bits->Bit_On(1);   # 1 is not prime
        $bits->Bit_Off(2);  # 2 is prime
        
        bless {
            sieve_size => $sieve_size,
            bits       => \$bits,
        }, $class;
    }

    sub bits {
        my $self = shift;
        return ${ $self->{bits} };
    }

    sub size {
        my $self = shift;
        return $self->{sieve_size};
    }

    sub ruler {
        my $size = shift;
        
        my $r = '9....v....8....v....7....v....6....v....5....v....4....v....3....v....2....v....1....v....0';
        my $rlen = length $r;
        my $excess
            = $rlen >= $size
            ? $rlen - $size
            : 0;
        substr($r, 0, $excess, '');
        return $r;
    }
    
    sub run_sieve {
        my $self   = shift;

        my $size   = $self->size;       # get once to avoid call overhead
        my $q      = sqrt $self->size;
        my $factor = 1;
        my $offset = 0;

        # say '      ', ruler($self->size);
        # say 'self: ', $self->bits->to_Bin;

        my $mask = Bit::Vector->new($self->size);

        while ( $factor <= $q ) {
            $factor += 2;

            $factor +=2 while $factor < $size && $self->bits->bit_test($factor);

            $mask->Empty;
            for ( my $i = $factor * $factor; $i < $size; $i += $factor * 2 ) {
                $mask->Bit_On($i);                
            }

            $self->bits->Or($self->bits, $mask);
        }

        # complement the bitmap so that 1 represents prime and 0 nonprime
        $self->bits->Not($self->bits);

        # say 'self: ',$self->bits->to_Enum;
    }

    sub print_results {
        my ( $self, $show_results, $duration, $passes ) = @_;

        my @primes = $self->primes();
        my $count = @primes;

        printf "%s\n", join ',', @primes
            if $show_results;

        my $f = $self->validate_results($count);
        printf "jgpuckering/$0;%d;%f;%d;algorithm=base,faithful=%s,bits=1\n", $passes, $duration, 1, $f;
        printf {*STDERR} "Passes: %d, Time: %f, Avg: %f, Limit: %d, Count: %d, Valid: %s\n",
          $passes, $duration, $duration / $passes,
          $self->size, $count, $f;
    }

    sub primes {
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
