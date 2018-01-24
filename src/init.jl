using Random

SAMANTHA_THREADS = haskey(ENV, "SAMANTHA_THREADS")

# Flush subnormals to zero for performance
set_zero_subnormals(true)
