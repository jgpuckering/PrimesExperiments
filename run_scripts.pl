#!/usr/bin/perl

# run_scripts.pl - Run primes scripts

# 2023 Gary Puckering <jgpuckering@rogers.com>

# Created from the 2023-07-10 version of template_new_script

# Done:
# -

# To Do:
# -

package RunScripts;

########################################################################
# Pragmas
########################################################################
use Modern::Perl '2021';    # enable features for perl 5.32

#<<< perltidy off
use feature 'signatures';
no  feature 'indirect';
no  warnings 'experimental::signatures';

use utf8;
use open qw( :std :utf8 );

########################################################################
# perlcritic rules
########################################################################

########################################################################
# Libraries
########################################################################

use CLU::Getoptions;
use CLU::IOSoptions;
use CLU::Msg;
use Const::Fast;
use English             qw( -no_match_vars );
use Capture::Tiny       qw( :all );
#>>> perltidy on

########################################################################
# Global delarations
########################################################################

our $VERSION = '1.001_000';

my $Opt;

my @Scripts = (
    # [ "primes_1_jgp.pl",        "using a list" ],
    # [ "primes_2_jgp.pl",        "using string bitmaps and perl's ability bitwise OR them" ],
    # [ "primes_pdl_1_jgp.pl",    "using PDL" ],
    # [ "primes_pdl_2_jgp.pl",    "using Inline PDL code" ],
    # [ "primes_3_substr.pl",     "uses a string with index(), substr() and looping" ],
    # [ "primes_3_bitwise.pl",    "uses a string with bitwise AND'ing to reduce looping" ],
    # [ "primes_3_inline.pl",     "uses a string and an inline C subroutine for byte changes" ],
    # [ "primes_2_noloop.pl",     "primes_2 using index()" ],
    # [ "primes_vec.pl",          "using the perl vec() operator and a set_rng() sub" ],
    # [ "primes_vec.pl",          "using the perl vec() operator with inline of set_rng()" ],
    # [ "primes_bitvec_1.pl",     "calling Bit::Vector primes()" ],
    # [ "primes_bitvec_2.pl",     "using Bit::Vector Bit_On() and loops" ],
    # [ "primes_substr.pl",       "primes_2 using loop and substr() for bit setting" ],
    # [ "primes_inlineC.pl",      "usine inline C set_bit_range()" ],
    # [ "PrimePY_1.py",           "using a list" ],
    [ "PrimePY_2.py",           "using a bytearray and array slicing" ],
    # [ "PrimePY_3.py",           "using numpy" ],
    # [ "PrimePY_2_jgp.py",       "using multi-byte slicer with step" ],
    # [ "PrimePY_2_jgp.py",       "using single-byte slicer and for loop with step" ],
    # [ "PrimePY_2_jgp.py",       "using for loop on byte array" ],

    # [ "PrimePY_2_jgp.pl",       "using a C subroutine to emulate python slicer syntax" ],
);

########################################################################
# Constants
########################################################################

const my $EMPTY => q();          # empty string
const my $SPACE => q( );         # space character
const my $TAB   => qq(\t);       # tab character
const my $TRUE  => 1;            # perl's usual TRUE
const my $FALSE => not $TRUE;    # a dual-var consisting of '' and 0

########################################################################
# Script Mainline
########################################################################

__PACKAGE__->run( \@ARGV ) unless caller;

#-----------------------------------------------------------------------
sub run ( $progname, $argv_ar )
{
    my @options = (
        'tsv',
        'size=i',
        'passes=i',
        'outclip',       # send output to the Windows clipboard
        'debug',              # enable debug() statements on STDERR
        'verbose+',           # display information messages on STDERR
    );

    $Opt = get_options( $argv_ar, @options );

    CLU::Msg->init($Opt);

    my $ios = CLU::IOSoptions->new( $Opt );

    say join $TAB, qw( Script Ident Passes Duration Threads Notes )
        if $Opt->tsv;
    
    foreach my $ar (@Scripts) {
        my ($script, $desc) = $ar->@*;

        my @opts;
        my $prog = 'perl';

        my (undef, $type) = split /[.]/, $script;
        $prog = 'python' if $type eq 'py';

        if ($Opt->size) {
            my $arg = '--size';
            $arg = '--limit' if $type eq 'py';
            push @opts, $arg, $Opt->size;
        }

        push @opts, '--passes', $Opt->passes if $Opt->passes;
        my $cmd = join $SPACE, $prog, $script, @opts;
        
        my ($stdout, $stderr) = capture {       
            system $cmd;
        };
        
        if ($Opt->tsv) {
            my @lines = split /\n/, $stdout;
            my @f = split /;\s*/, $lines[0];
            say join $TAB, $script, @f;
        } else {
            say $script;
            say $stdout;            
        }
    }

    $ios->finish;

    return;
}

########################################################################
# Subroutines
########################################################################

1;    # in case we import this as a module (e.g. for testing)

########################################################################
# Documentation
########################################################################
__END__

=head1 NAME

run_scripts.pl - Run primes scripts

=head1 SYNOPSIS

    run_scripts.pl [file...]
                   [-output] [-debug] [-verbose]+

    run_scripts.pl [--help | -? | --usage]

=head1 DESCRIPTION

Run primes scripts

=head1 PARAMETERS

Getoptions::Long is used, so either - or -- may be used.  Parameter
names may be abbreviated, so long as they remains unambiguous.  Flag
options may appear after filenames. If no input options are selected,
input lines are taken from stdin.

=over 4

=item -file...

Take input from files.

=item -outclip

Send output to the Windows clipboard.

=item -debug

Enables debug() statements (see perldoc Msg).

=item -verbose

Lowers message level threshold (see perldoc Msg).
May be used multiple times.

=item -h | -help

Display this documentation.

=back

=head1 AUTHOR

Gary Puckering (jgpuckering@rogers.com)

=head1 LICENSE AND COPYRIGHT

Copyright 2023, Gary Puckering

=cut
