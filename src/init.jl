using Compat
import Compat.Random
import Compat.@info
import Compat.axes
using Parameters
using OnlineStats
@static if VERSION < v"0.7-"
  import Base.Random: UUID, uuid4
else
  import UUIDs: UUID, uuid4
end

SAMANTHA_THREADS = haskey(ENV, "SAMANTHA_THREADS")

# Flush subnormals to zero for performance
set_zero_subnormals(true)
