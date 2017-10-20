### Exports ###

export fasttanh, canthread

### CPU Optimizations ###

set_zero_subnormals(true)

fasttanh(x) = x * ( 27 + x * x ) / ( 27 + 9 * x * x )

canthread() = SAMANTHA_THREADS && !Threads.in_threaded_loop.x && Threads.nthreads() > 1
