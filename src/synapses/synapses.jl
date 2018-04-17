### Methods ###

function eforward!(synapses::CPUContainer{S}, args#=::Vector{Tuple{Symbol,AbstractContainer}}=#) where S<:AbstractSynapses
  dstnodes = collect(args)

  inputs = map(t->t[3], filter(t->t[1]==:input, dstnodes))
  @assert length(inputs) == 1 "Incorrect number of inputs: $(length(inputs))"
  input = inputs[1]

  outputs = map(t->t[3], filter(t->t[1]==:output, dstnodes))
  @assert length(outputs) == 1 "Incorrect number of outputs: $(length(outputs))"
  output = outputs[1]

  rewards = map(t->(t[2],t[3]), filter(t->t[1]==:reward, dstnodes))

  if length(rewards) == 0
    _eforward!(synapses, input, output)
  else
    _eforward!(synapses, input, output, rewards)
  end
end

### Includes ###

include("learn.jl")
include("modify.jl")
include("generic/core.jl")
include("conv/core.jl")
