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
include("neurons/neurons.jl")
include("synapses/synapses.jl")
include("agent.jl")
include("interface.jl")

# Standard Library
include("Stdlib.jl")

# External Optional Dependencies
include("external/External.jl")

end
