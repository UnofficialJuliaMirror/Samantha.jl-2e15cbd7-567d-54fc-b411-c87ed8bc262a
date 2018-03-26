### Methods ###

function eforward!(synapses::CPUContainer{S}, args#=::Vector{Tuple{Symbol,AbstractContainer}}=#) where S<:AbstractSynapses
  inputs = map(t->t[2], filter(t->t[1]==:input, args))
  @assert length(inputs) == 1 "Incorrect number of inputs: $(length(inputs))"
  input = inputs[1]

  outputs = map(t->t[2], filter(t->t[1]==:output, args))
  @assert length(outputs) == 1 "Incorrect number of outputs: $(length(outputs))"
  output = outputs[1]

  _eforward!(synapses, input, output)
end

### Includes ###

include("learn.jl")
include("modify.jl")
include("generic/core.jl")
include("conv/core.jl")
