Primes Experiments
==================

Introduction
------------

This folder contains my attempts at developing faster versions of a
perl script that will calculate primes using the sieve of Erasthones
algorithm.

I undertook this project after seeing an episode of Dave's Garage on
YouTube.  Dave is a former Microsoft developer who was responsible
for, among other things, Windows Task Manager.  The episode was "Top
5 Fastest Programming Languages" (see https://youtu.be/pSvSXBorw4A)
from 2023-03 in which over a hundred languages are compared.  Dave
began the competition a year prior, with solutions in C#, C++ and
Python that he put in a GitHub repo.  Following that, developers
jumped in to contribute solutions in other languages, or to offer
faster solutions, and to build a framework for continuous build and
execution of the solutions.

All the solutions can be found in the following GitHub repo:
https://github.com/PlummersSoftwareLLC/Primes

There is also a web application that can be used to view the results
of all the various runs:
https://plummerssoftwarellc.github.io/PrimeView/


Environment
-----------

My own solutions were executed on my Dell XPS 8940 desktop computer
with the following characteristics:

    OS Name                           Microsoft Windows 11 Pro
    Version                           10.0.22621 Build 22621
    System Type                       x64-based PC
    Processor                         11th Gen Intel(R) Core(TM) i7-11700
                                      @ 2.50GHz, 2501 Mhz, 8 Core(s) 16 Logical
    Installed Physical Memory (RAM)   16.0 GB
    Total Physical Memory             15.6 GB
    Available Physical Memory         6.69 GB
    Total Virtual Memory              22.3 GB
    Available Virtual Memory          9.01 GB
    Page File Space                   6.68 GB
    Page File                         C:\pagefile.sys

The software I used was:
    perl 5, version 32, subversion 1 (v5.32.1) built for MSWin32-x64-multi-thread
    Python 3.10.11

Benchmarking and Profiles
-------------------------

The scripts contain their own benchmark code following Dave's design.
A timer is set and run_sieve() is called repeatedly until 5 seconds
has elapsed.  Then statistics are reported.

To achieve more reliable results, I turned of Wi-Fi, LAN networking and
Bluetooth during the test period.

I used the NYTProfile module from CPAN to do detailed profiling of each
script execution and saved the results as HTML in folders named
nytprof_<script>.  The instructions are as follows:

    perl -d:NYTProfile <script>.pl
    nytprofhtml -o nytprof_<script>


Results of GitHub perl solutions
--------------------------------

primes_1.pl - using a list
    Passes: 68, Time: 5.016747, Avg: 0.073776, Limit: 1000000, Count: 78498, Valid: yes
    marghidanu; 68; 5.016747; 1; algorithm=base,faithful=yes

    This implementation uses a list as the bitmap.  Lists are not arrays
    not bitmaps so this approach is costly in both space and time.

primes_2.pl - using string bitmaps and perl's ability bitwise OR them
    Passes: 161, Time: 5.022658, Avg: 0.031197, Limit: 1000000, Count: 78498, Valid: yes
    kjetillll; 161; 5.022658; 1; algorithm=base,faithful=yes,bits=8

    This implementation creates a sieve-sized string of 1's and 0's
    as the main "bitmap".  It uses substr() to inspect bits, but not
    to set bits.  Instead it cleverly leverages the fact that perl's
    bitwise OR operator can operate on strings of 1's and 0's.

    To set bits it creates a mask of bits 0's the length of sqrt(factor).
    When OR'd with the main map this ensures the entries in that range
    are left unchanged.

    Above sqrt(factor) it sets bits for each multiple of factor by
    constructing a bitmap that is two factors wide.  The initial bit
    is set to 1.  Then it replicates that bitmap as many times as
    necessary to reach the end of the sieve.

    The reason why the bitmap can be two factors wide instead of just
    one is that factor is always an odd number and 2*factor will always
    be an even numbers.  So a single mask two factors wide will do the
    job of two masks where one has the leading bit set and the other
    doesn't.

    Concatenating the sub-sqrt(factor) mask and the replicated 2-factor
    masks provides a complete mask that can be OR'd with the main map.

    Replication of the 2-factor mask is done using the perl 'x' operator
    and so it executed without an interpreter loop.  OR'ing is done
    with the bitwise OR operator, therefore also avoiding an interpreter
    loop.

    The main overhead comes from replicating and concatenating the
    masks components into a single mask, and from whatever perl does
    internally to OR string bitmaps.  Profiling shows that during
    the 5 seconds of execution, about 2.32 seconds are spent doing
    the mask string construction, and 2.63 seconds in the OR operation.
    Together that's 99.4% of the time spent in run_sieve.

    This script has only use strict and use warnings pragmas enabled.
    It uses the | operator for OR.  In perl 5.22, the 'bitwise' feature
    was added to make the four standard bitwise operators ( & | ^ ~ )
    and assignment variants (&= |= ^= &.= |.= ^.=) treat their operands
    consistently as numbers rather than strings.  When use feature 'bitwise'
    is enabled, string operators &. |. ^. ~. and their assignment variants
    become available.  When the 'bitwise' feature is in effect, perl
    will complain if you use the wrong type of operand.   Starting in
    Perl 5.28, use v5.28 will enable the feature. Before 5.28, it was
    still experimental and would emit a warning in the
    "experimental::bitwise" category.

    All this to say that if you add something like use Modern::Perl
    at the top of this script, you'll end up enabling the bitwise feature.
    and perl will complain unless you change the OR operator to |.=

primes_pdl_1.pl - using PDL
    Passes: 773, Time: 5.003902, Avg: 0.006473, Limit: 1000000, Count: 78498, Valid: yes
    Luis_Mochán_(wlmb)_Perl/PDL; 773; 5.003902; 1; algorithm=base,faithful=yes,bits=8

    Uses Perl Data Language (similar to Python numpy) for more efficient
    bit manipution.  This version uses a byte array and imports
    the module Nice::Slice so that it can loop and set bits using
    this syntax:

        my $one = pdl(byte, 1);
        for (my $factor = 3; $factor <= $q; $factor += 2) {
            $bits( $factor * $factor : -1 : 2 * $factor ) .= $one
                unless $bits( ($factor) );
        }

perl primes_pdl_2.pl - using Inline PDL code
    Passes: 1253, Time: 5.000292, Avg: 0.003991, Limit: 1000000, Count: 78498, Valid: yes
    Luis_Mochán_(wlmb)_Perl/PDL-PP; 1253; 5.000292; 1; algorithm=base,faithful=yes,bits=8

    Uses Perl Data Language (similar to Python numpy) for more efficient
    bit manipution.  Unlike perl_pdl_1.pl, which used PDL bit operations
    on bytes within a perl for() loop, this version uses the Inline module with
    language 'Pdlpp' to implement the entire sieve in PDL language using
    bits -- and compiling that into a DLL.

    use Inline Pdlpp => <<'EOPP';
        pp_def('run_sieve_aux',
            Pars=>'[io]bits(n);factors(q);',
            Code=>q{
                int f, i, f2, ff, sn;
                loop(q) %{
                    f = $factors();
                    if ( $bits( n => f ) == 0 ) {
                        f2 = 2*f;
                        ff = f*f;
                        sn = $SIZE(n);
                        for ( i = ff; i < sn; i += f2) {
                            $bits( n => i ) = 1;
                        }
                    }
                %}
            },
        );
    EOPP

Results of my solutions
-----------------------

primes_2_noloop.pl - primes_2 using index()
    Passes: 149, Time: 5.008612, Avg: 0.033615, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/primes_2_noloop.pl; 149; 5.008612; 1; algorithm=base,faithful=yes,bits=8

    This solution is essentially a clone of primes_2, but instead of
    a while loop to find the next non-prime is uses index() -- like
    the Python implementation does.  However, this did not provide
    much improvement in that specific area of code.

primes_substr.pl - primes_2 using loop and substr() for bit setting
    Passes: 123, Time: 5.004201, Avg: 0.040685, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/primes_substr.pl; 123; 5.004201; 1; algorithm=base,faithful=yes,bits=8

    This solution, like primes_2, uses a string as a bitmap and substr
    to look at or set bits.  The big difference is that it uses a
    straightforward for() loop to set bits beyond factor-squared,
    whereas primes_2 constructed a string bitmask and then used
    bitwise OR to set the bits thus avoiding costly interpreter looping.
    The for() loop definitely hurts the performance of this solution.

primes_vec_1.pl - using the perl vec() operator and a set_rng() sub
    Passes: 31, Time: 5.055305, Avg: 0.163074, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/primes_vec_1.pl; 31; 5.055305; 1; algorithm=base,faithful=yes,bits=8

    This was an attempt to use the most obvious solution to managing
    bitmaps in perl -- the vec() operator.  It uses a subroutine
    called set_rng to set bits across a range using a step, but the
    implementation of that simply loops and calls vec().  Interpreter
    loops are slow, so this solution performs very poorly.

    I profiled this with and without the subroutine (i.e. inlining
    the set_rng code) and found that calling the subroutine was
    often about 20 ms faster for some reason I don't understand.

primes_vec_2.pl - using the perl vec() operator and loop
    Passes: 28, Time: 5.082888, Avg: 0.181532, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/primes_vec_2.pl; 28; 5.082888; 1; algorithm=base,faithful=yes,bits=8

    Use vec() by directly looping (no subroutine) and setting the bits
    that are beyond each factor.  Once again, the performance suffers
    greatly due to the interpreter loop.


primes_bitvec_1.pl - calling Bit::Vector primes()
    Passes: 2735, Time: 5.001112, Avg: 0.001829, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/primes_bitvec_1.pl; 2735; 5.001112; 1; algorithm=base,faithful=yes,bits=1

    Uses CPAN module Bit::Vector

primes_bitvec_2.pl - using Bit::Vector Bit_On() and loops
    Passes: 49, Time: 5.076909, Avg: 0.103610, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/primes_bitvec_2.pl; 49; 5.076909; 1; algorithm=base,faithful=yes,bits=1

primes_inlineC.pl - usine inline C set_bit_range()
    Passes: 2909, Time: 5.001026, Avg: 0.001719, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/inlineC; 2909; 5.001026; 1; algorithm=base,faithful=yes,bits=8


Results of GitHub python solutions
----------------------------------

PrimePY_1.py - using a list
    Passes: 489, Time: 5.000779, Avg: 0.010226541, Limit: 1000000, Count: 78498, Valid: True
    davepl; 489; 5.000778500; 1; algorithm=base,faithful=yes

PrimePY_2.py - using a bytearray and array slicing
    Passes: 3852, Time: 5.000281500, Avg: 0.001298100, Limit: 1000000, Count: 78498, Valid: True
    ssovest;  3852; 5.000281500; 1; algorithm=base,faithful=yes,bits=8

PrimePY_3.py - using numpy
    Passes: 10453, Time: 5.000337200, Avg: 0.00047836383813, Limit: 1000000, Count: 78498, Valid: True
    emillynge_numpy;  10453; 5.000337200; 1; algorithm=base,faithful=no,bits=8


The Algorithm
-------------

The sieve of Eratosthenes is a procedure for finding prime numbers
up to N.  The procedure is:

    1. Writing down the integers from 0 to N-1
    2. Cross out 0 because it is considered non-prime
    3. Starting with factor 3, cross out every multiple of 3
       (leaving three unmarked)
    4. Increment the factor by 2 and cross its multiples
    5. When the factor exceeds sqrt(N) you can stop
    6. The uncrossed numbers are prime

The time complexity of this algorithm is O( n log log n ).

A common set of optimizations (to save loops and bit inspection/setting)
 is to:
    -  Just before step 3, cross out all even numbers in the list
    -  At steps 3 and 4, skip every other multiple since those will
       be even numbers and already crossed out

See https://en.wikipedia.org/wiki/Sieve_of_Eratosthenes
and https://en.wikipedia.org/wiki/Eratosthenes


Analysis
--------

All the perl implementations suffered when they had to loop over the
map using for() or while().  These loops are done in the perl
interpreter and are painfully slow compared to executing native
operations or compiled code.

The primes_2 implementation was the fastest native solution (i.e. not
using PDL or a DLL).  Its clever use of strings as bitmaps and perl's
ability to do bitwise operations on them enabled that solution to
avoid the most expensive loop:  setting bits for the factor multiples.

To isolate and compare the bitstring-OR approach versus an
interpreter loop, I cloned primes_2 into primes_2_jgp and altered
main to use Getopt::Long in support of command line options that told
the script to either run a set number of passes, or to run until a
set time limit.  Also to control sieve size.

I then cloned that to produce primes_substr, in which the
bitstring-OR is replaced with a for() loop and substr() for bit
inspection and setting.

Running 30 passes of these scripts generated the following results:

  primes_2_jgp
    Passes: 30, Time: 2.211002, Avg: 0.073700, Limit: 1000000, Count: 78498, Valid: yes

  primes_substr
    Passes: 30, Time: 1.216293, Avg: 0.040543, Limit: 1000000, Count: 78498, Valid: yes

I also tried using the vec() operator, which seemed to be the most
obvious way to do bit setting in perl.  However, it performed somewhat
worse than substr -- though it probably saved on memory.  There's more
bookeeping to do when setting any of 8 bits within a byte versus just
setting one bit in each byte.  In the end, vec() was convenient but
not more so than substr.

Both vec and substr lack a slicing a stepping capability.  If either
had that, it would have enable a solution comparable to PrimePY_2.py.

The CPAN module Bit::Vector offered hope since it provides XS routines
written in C that do a variety of bitmap operations.  Unfortunately it
too lacked a step option for bit setting across a range and thus
necessitated the use of slow-running interpreter loops.


Inline to the rescue
--------------------

What was needed was a custom bit-setting subroutine in written in C
and callable from perl.  It would be used in the most loop-intensive
section of the algorithm.

Writing C code for use with perl has traditionally meant setting up a
rather complicated environment for XS and becoming intimately
familiar with these documents: perlxs perlxstut perlapi perlguts
perlmod h2xs xsubpp ExtUtils::MakeMaker.

Fortunately, there is an alternative.  The CPAN Inline module enables
perl users to write inline code in various languages (notably C).
See:

    https://metacpan.org/pod/Inline
    https://metacpan.org/pod/Inline::C
    https://metacpan.org/dist/Inline-C/view/lib/Inline/C/Cookbook.pod

It turned out to be very easy to use.  All I needed was to add the
following to my script:

    use Inline C => <<~'__C__';
        void set_bit_range(char *str, int start, int stop, int step, char* v) {
            int i = 0;

            for (i=start; i<stop; i+=step) {
                str[i] = v;
            }
        }
    __C__

This simple C function does the workhorse job of setting bit at
regular step-sized intervals between the start and stop positions.
A string bitmap is used because strings are easy to manipulate in both
perl and C, and based on other solutions are likely the fastest to
access and update.  Though not as compact as the bit vectors we get
from using vec() or Bit::Vector, the tradeoff of space vs time is
worth it.

Of course, the entire seive algorithm could be implemented in C.  But
I crafted this routine as a perl analog of python's bytearray slicing
with stepping feature.  This was to enable a fair comparison between
the languages.


The PrimePY_2.py algorithm
--------------------------

PrimePY_2.py uses a bytearray and index slicing to achieve better
performance than PrimePY_1 (which uses lists and loop indexing). But
it also uses a different algorithm -- one which cuts the sieve size
in half.

Since even numbers are nonprime (except 2, a special case), the PrimePY_2
algorithm uses a sieve that only contains odd numbers.  It also inverts
the usual 0/1 meaning for 0 = nonprime / 1 = prime to 0 = prime and
1 = nonprime.  Therefore it begin by initializing a bytearray that is
one-half the seive size to all 1's.  Then it clears bits for factor
multiples.

Where it gets a performance boost over many other implementations and
languages is that to mark off factor multiples it constructs a bytearray
of zeros for the number of multiples and assigns that to a slice of
the bytearray which is constructed using [start : stop : step] indexing
syntax.  No intepreter loop is needed for the this -- Python does
the work internally, likely in a C routine and at machine speed.

Comparing apples to apples
--------------------------

None of the perl solutions in the GitHub repository were properly
comparable to the python solutions.  I did some benchmark testing
of looping and string indexing with replacement and determined that
python and perl have comparable speeds when doing such tasks.  So
the big difference in performance between the python scripts and the
perl scripts must lie in the algorithm.

I prepared a clone of primesPY_2.py and a matching perl primes_py2.pl
script.  For the perl script I used the exact same algorithm as the
python script.  The only difference was in the marking of multiples.
Since perl doesn't have slicer syntax with steps, I wrote an inline
C routine to do that work.  I also added a command line option so I could
run the script with the C routine or with an equivalent perl routine.

primes_py2.pl - using a perl subroutine to emulate python slicer syntax
    Passes: 104, Time: 5.048813, Avg: 0.048546, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/primes_py2.pl;104;5.048813;1;algorithm=base,faithful=yes,bits=8
    perl loops = 84368648  set_rng_inline C loops = 0

perl primes_py2.pl - using a C subroutine to emulate python slicer syntax
    Passes: 9865, Time: 5.000291, Avg: 0.000507, Limit: 1000000, Count: 78498, Valid: yes
    jgpuckering/primes_py2.pl;9865;5.000291;1;algorithm=base,faithful=yes,bits=8
    perl loops = 1657320  set_rng_inline C loops = 829160431720

PrimePY_2_jgp.py
    Passes: 3424, Time: 5.000426, Avg: 0.001460, Limit: 1000000, Count: 78498, Valid: True
    ssovest; 3424;5.000426;1;algorithm=base,faithful=yes,bits=8
    python loops = 168  slicer steps = 395614713304

As these results demonstrate, the python script managed over 3,400 passes
compared to a meagre 104 passes for the pure perl script.  But the
perl script using the C routine to emulate array slicing with steps
turned in over 9,800 passes.

Another embellishment I added to these scripts was to count the
number of perl/python interpreter loop and the number of machine
loops that occurred within the inline C subroutine or the python
array slice replacement. I tried this for various sieve sizes and got
the following counts:

     ---------- interpreter loops -----------
          Size      perl       perl    python
                 (inline C)   (pure)
         1,000         10        470       10
        10,000         25      6,021       25
       100,000         65     71,622       65
     1,000,000        168    811,237      168

     ---------- machine loops ---------------
         1,000        507          0      457*
        10,000      6,120          0    5,995*
       100,000     71,881          0   71,556*
     1,000,000    811,908          0  811,060*

     * estimated, not actually counted

Note that the pure perl script experiences an exponential growth in
interpreter loops as the sieve size increases, whereas the python script
and its perl with inline C analog do not.  For those two scripts the
exponential increase happens inside machine loops.  This accounts for
the poor performance of the pure perl scripts relative to the python
scripts.

Returning the list of primes
----------------------------

The first script in the database, primes_1.pl, uses a for() loop to
find the primes in the bitmap and print them.  In primes_2.pl, this
was done with a funky pair of grep calls like this:

    grep !substr($$bits,$_,1),
         2,
         grep $_ % 2, 3 .. $self->{sieve_size};

It was tempting to think that using grep rather than writing a loop
would be faster, but I benchmarked 100 iterations of grep vs loop using
primes_vec_2.pl and looping was faster by a significant margin.

    jgpuckering/primes_vec_2.pl;1;0.179584;1;algorithm=base,faithful=yes,bits=8
           Rate grep loop
    grep 17.7/s   -- -47%
    loop 33.2/s  87%   --


I suspect the reason the loop was faster is that the grep solution first
instantiates a sieve-sized list of integers, then iterates over them
to find the odd numbers, then that list is grep'd and filtered against
the primes map to eliminate the remaining non-primes.  The loop
solution scans the entire primes map only once.  Using grep this way
was clever, but not a better choice than a straightforward loop.

In the end, however, the difference is not material to the overall
execution speed of the script.

Conclusion
----------

Python 3 is remarkably fast even when using interpretor loops and a
list as a bitmap.  It beat all the GitHub perl solutions hands down.

Python performance got even better when using a bytearray with array
slicing using stepping -- a feature perl does not have.  And performance
soared when using numpy.

The GitHub perl with PDL solution was by far the fastest perl solution,
but it was still slower than Python.  PDL, however, also suffers from
the lack of a step option when byte slicing.

Pushing the byte slicing down into an inline C subroutine made a 
dramatic difference in perl performance.  This leveled the playing 
field between perl and python.  If perl had a byte slice function 
that supported steppping and replacement, it would have come out 
roughly even with of python in this particular benchmark.

One drawback to using the Sieve of Eratosthenes as a benchmark is 
that it is heavily skewed towards measuring raw interpreter looping 
speed - especially as the sieve size increases.  

In many applications, looping is handled within builtin functions or 
operators making the results from this benchmark of limited 
applicability in the real world.  On any benchmark where the need for 
looping grows exponentially with the data size, it matters a great 
deal in interpreted languages how much of the looping can be 
relegated to functions that execute machine code.

Python's array slicing with optional stepping is a feature missing 
from perl that would have been very helpful for this benchmark.  
However, the absence of this feature in perl (and in CPAN) is likely 
an indication that its usefulness in the real world is limited.  Perl 
does have index slices, but not with stepping and not on strings.  If 
such capabilities were needed often, they'd likely have been provdied 
in a CPAN module implemented with XS and C code.

In the rare cases where a perl script needs to execute thousands of
loops, the Inline module provides an easy way to write C (or PDL) code
that can push intensive operations down into machine code.

When perl with inline C is compared to python with numpy, using the 
same algorithm, the results are actually very close:  10,621 passes 
for perl vs 10,970 passes for python.

