mutable struct SynapticConnection{D}
  uuid::UUID
  op::Symbol
  data::D
end

@with_kw mutable struct SynapticInput{Frontend,LearnAlg,NDims}
  inputSize::Int
  outputSize::Int

  condRate::Float32 = 0.1
  traceRate::Float32 = 0.5

  frontend::Frontend = GenericFrontend(inputSize, 1)
  learn::LearnAlg = SymmetricRuleLearn()

  C::Array{Float32,NDims} = zeros(Float32, outputSize, inputSize)
  W::Array{Float32,NDims} = rand(Float32, outputSize, inputSize)
  M::Array{Bool,NDims} = ones(Bool, outputSize, inputSize)
  T::Array{Float32,NDims} = zeros(Float32, outputSize, inputSize)
  O::Vector{Float32} = zeros(Float32, outputSize)
end
# FIXME: Apply conf
function SynapticInput(ncont::CPUContainer{N} where N<:GenericNeurons, outputSize, conf)
  n = root(ncont)
  SynapticInput(;inputSize=size(n), outputSize=outputSize)
end

@with_kw mutable struct SynapticOutput
  outputMask::Float32=1.0
end
# FIXME: Apply conf
function SynapticOutput(ncont::CPUContainer{N} where N<:GenericNeurons, conf)
  n = root(ncont)
  SynapticOutput()
end

@with_kw mutable struct RewardModulator{Frontend,LearnAlg,NDims}
  inputSize::Int
  outputSize::Int
  inputIndex::Int

  frontend::Frontend = GenericFrontend(inputSize, 1)
end

#=
modulate!(state, node, mod::Nothing) = state
@with_kw mutable struct FunctionalModulator{OF<:Function,IF}
  outer::OF
  inner::IF = nothing
end
modulate!(state, node, mod::FunctionalModulator) = mod.func(modulate!(state, node, mod.inner), node)
=#

#@with_kw mutable struct RewardModulator
#  avgReward::Mean = RewardModulator(Mean(weight=ExponentialWeight()))
#end
function modulate!(state, node::GenericNeurons, mod::RewardModulator)
  rF = node.state.F
  rw = mean(rF)
  #fit!(learnRate, rw-value(mod.avgReward))
  #fit!(mod.avgReward, rw)
  # TODO
end

### Methods ###

function reinit!(conn::C where C<:SynapticInput)
  @unpack frontend, C, W, T = conn
  reinit!(frontend)
  fill!(C, 0f0)
  rand!(W, 0f0:0.01f0:1f0)
  fill!(T, 0f0)
end
reinit!(conn::C where C<:SynapticOutput) = nothing

eforward!(synapses::CPUContainer{S}, args) where S<:AbstractSynapses =
  _eforward!(synapses, args)
#=
function eforward!(synapses::CPUContainer{S}, args) where S<:AbstractSynapses
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
=#

### Includes ###

include("learn.jl")
include("modify.jl")
include("generic/core.jl")
include("conv/core.jl")
