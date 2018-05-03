using Compat
import Compat.Random
import Compat.@info
import Compat.axes
using OnlineStats

SAMANTHA_THREADS = haskey(ENV, "SAMANTHA_THREADS")

# Flush subnormals to zero for performance
set_zero_subnormals(true)
