import timeit
from math import sqrt


SieveSize = 1000000
Iter = 200
PrintPrimes = 0

# SieveSize = 60
# Iter = 1

stats = { 
    'allocate'  : 0, 
    'inspect'   : 0, 
    'set to zero'  : 0, 
    'sieve'     : 0 
};

def allocate(size):
    tStart = timeit.default_timer()
    bytes = bytearray(b"\x01") * ((size + 1) // 2)
    dur = timeit.default_timer() - tStart
    stats['allocate'] += dur
    return bytes

def inspect(bytes):
    byteslen = len(bytes)
    tStart = timeit.default_timer()
    for idx in range (0,byteslen-1, 1):
        if bytes[idx]:
            pass
    dur = timeit.default_timer() - tStart
    stats['inspect'] += dur

def set_to_zero(bytes):
    byteslen = len(bytes)
    tStart = timeit.default_timer()
    for idx in range (0,byteslen-1, 1):
        bytes[idx] = 1
    dur = timeit.default_timer() - tStart
    stats['set to zero'] += dur

def sieve(bytes, size):
    """Calculate the primes up to the specified limit"""

    tStart = timeit.default_timer()

    factor = 1
    # sqrt doesn't seem to make any difference in CPython,
    # but works much faster than "x**.5" in Pypy
    q = sqrt(size) / 2
    byteslen = len(bytes)

    while factor <= q:
        factor = bytes.index(b"\x01", factor)

        # If marking factor 3, you wouldn't mark 6 (it's a mult of 2) so start with the 3rd instance of this factor's multiple.
        # We can then step by factor * 2 because every second one is going to be even by definition
        start = 2 * factor * (factor + 1)
        step  = factor * 2 + 1
        offset  = byteslen - start
        bytes[start :: step] = b"\x00" * (offset // step + bool(offset % step))  # bool is (a subclass of) int in python

        factor += 1

    dur = timeit.default_timer() - tStart
    stats['sieve'] += dur
    if PrintPrimes:
        primes = get_primes(bytes)
        print(primes)

def get_primes(bytes):
    print(bytes)
    primes = list()
    if len(bytes) > 1:
        primes.append(2)
    if len(bytes) > 2:
        num = 1
        while num > 0:
            primes.append(num * 2 + 1)
            num = bytes.find(1, num + 1)
    return primes
            
### Mainline ########################################################

for n in range(1,Iter+1):
    bytes = allocate(SieveSize)
    inspect(bytes)
    set_to_zero(bytes)
    sieve(bytes,SieveSize)
    # if size is 1 million, there should be 78498 primes
    # print("Found %s primes" % count_primes(bytes, byteslen))

for label in stats:
    byteslen = len(bytes)
    fmt = '{t:15s} {it:4d} {sz:8d} {d:.6f}'
    print(fmt.format(t=label,it=Iter,sz=byteslen,d=stats[label]))

