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
  learn::LearnAlg = HebbianDecayLearn()

  C::Array{Float32,NDims} = zeros(Float32, outputSize, inputSize)
  W::Array{Float32,NDims} = rand(Float32, outputSize, inputSize)
  M::Array{Bool,NDims} = ones(Bool, outputSize, inputSize)
  T::Array{Float32,NDims} = zeros(Float32, outputSize, inputSize)
  O::Vector{Float32} = zeros(Float32, outputSize)
end
# FIXME: Apply conf
function SynapticInput(dstcont::CPUContainer, outputSize, conf)
  dstnode = root(dstcont)
  SynapticInput(;inputSize=size(dstnode), outputSize=outputSize)
end

### Methods ###

function reinit!(conn::SynapticInput)
  @unpack frontend, C, W, T = conn
  reinit!(frontend)
  fill!(C, 0f0)
  rand!(W, 0f0:0.01f0:1f0)
  fill!(T, 0f0)
end

### Includes ###

include("learn.jl")
include("modulate.jl")
include("generic.jl")
include("conv.jl")
