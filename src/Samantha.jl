__precompile__(true)

module Samantha

# Core files
include("init.jl")
include("imports-exports.jl")
include("abstracts.jl")
include("util.jl")
include("container.jl")
include("macros.jl")
include("defaults.jl")
include("h5.jl")
include("neurons/neurons.jl")
include("synapses/synapses.jl")
include("agent.jl")
include("mutate.jl")
include("evolve.jl")
include("optimize.jl")

# Standard Library
include("Stdlib.jl")

end
