#!/usr/bin/perl

use strict;
use warnings;

# Enable distinct operators for bitwise integer and bitwise string operations
#   e.g. & | ^ ~ for integers and |. &. ^. ~. for strings 
#        (and their assignment variants |.= &.= ^.= ~.=)
use feature 'bitwise';

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

            # Implementation primes_2.pl uses a while construct to find
            # the next factor; i.e.
            #
            #   $factor += 2 while $factor < $size and substr($$bits,$factor,1);
            #
            # Using an interpreter loop carries a lot of overhead so
            # this implementation (like the python implementation) uses
            # index() to find the next factor.
            #
            # However, comparison testing suggests this doesn't save
            # much time -- probably because the number of iterations
            # to find the next factor is small.

            if ( substr($$bits, $factor,1) ) {
                my $ii = index($$bits, '0', $factor);
                $factor = $ii if $ii > 0;
            }

            my $factor_sq = $factor**2;

            # construct a factor bit mask that will be OR'd with the bit
            # string at each position that is multiple of the factor.
            # The mask it twice factor in length because factor * 2
            # will be an even number and doesn't need to be marked

            my $fmask = '0' x ($factor*2);
            substr($fmask,0,1) = '1';

            # determine how many times we'll need to mask multiples
            # after sqrt(factor)
            my $times = 1 + ( length($$bits) - $factor_sq ) / 2 / $factor;

            last if $times < 0;

            # construct the final mask from a mask of zeroes that
            # skips over everything up to sqrt(factor) and then
            # masks each muliple of factor beyond sqrt(factor)
            my $s = 0 x $factor_sq  .  $fmask x $times;

            $$bits |.= $s;

            # printf "factor %d factor*2 %d factor**2 %d times %d\n", $factor, $factor*2, $factor_sq, $times;
            # printf "s    %s\n", $s;
            # printf "bits %s\n", $$bits;

            #      0         1         2         3         4         5
            #      012345678901234567890123456789012345678901234567890123456789

            # bits 0000101010101010101010101010101010101010101010101010101010101
            # s    000000000100000100000100000100000100000100000100000100000100000
            # bits 000010101110101110101110101110101110101110101110101110101110100
            # s    00000000000000000000000001000000000100000000010000000001000000000
            # bits 00001010111010111010111011111010111110111010111010111011111010000
            # s    00000000000000000000000000000000000000000000000001000000000000010000000000000
            # bits 00001010111010111010111011111010111110111010111011111011111010010000000000000
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
