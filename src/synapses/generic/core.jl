### Exports ###

export GenericConfig, GenericState, GenericSynapses

### Types ###

@nodegen mutable struct GenericFrontend
  delayLength::Int

  D::RingBuffer{Bool}
  #ID::Vector{Int}
end
GenericFrontend(inputSize::Int, delayLength::Int) = GenericFrontend(delayLength, RingBuffer(Bool, inputSize, delayLength))
@nodegen mutable struct RewardModulator
end
#RewardModulator
@nodegen mutable struct GenericSynapses{F, L, S} <: AbstractSynapses
  inputSize::Int
  outputSize::Int
  outputMask::Float32
  condRate::Float32
  traceRate::Float32

  frontend::F
  learn::L

  C::Array{Float32,S}
  W::Array{Float32,S}
  M::Array{Bool,S}
  T::Array{Float32,S}

  modulators::Vector{Tuple{String,RewardModulator}}
end
GenericSynapses(inputSize::Int, outputSize::Int; outputMask=1, condRate=0.1, traceRate=0.5, delayLength=1, learn=SymmetricRuleLearn()) =
  GenericSynapses(
    inputSize,
    outputSize,
    Float32(outputMask),
    Float32(condRate),
    Float32(traceRate),

    GenericFrontend(inputSize, delayLength),
    learn,

    zeros(Float32, outputSize, inputSize),
    rand(Float32, outputSize, inputSize) * 0.3f0,
    ones(Bool, outputSize, inputSize),
    zeros(Float32, outputSize, inputSize),

    Tuple{String,RewardModulator}[]
  )
GenericSynapses(size::Tuple{Int,Int}; kwargs...) = GenericSynapses(size[1], size[2]; kwargs...)

### Edge Patterns ###

#@edgepattern GenericSynapses (:input=>GenericNeurons, :output=>GenericNeurons) sizes->(sizes[:input]*sizes[:output])
@edgepattern GenericSynapses (:input=>ConvNeurons, :reward=>GenericNeurons) sizes->(sizes[:input]*sizes[:reward])

### Methods ###

function addedge!(synapses::GenericSynapses, dstcont, dst, op)
  @assert op in [:input, :output, :reward] "Cannot handle op $op"
  if op == :reward
    push!(synapses.modulators, (dst, RewardModulator()))
  end
end
function deledge!(synapses::GenericSynapses, dst, op)
  if op == :reward
    synapses.modulators = filter(m->m[1]==dst, synapses.modulators)
  end
end
function resize!(synapses::GenericSynapses, new_size)
  old_size = size(synapses)
  synapses.inputSize = new_size[1]
  synapses.outputSize = new_size[2]
  synapses.C = resize_arr(synapses.C, new_size)
  synapses.W = resize_arr(synapses.W, new_size)
  synapses.M = resize_arr(synapses.M, new_size)
  synapses.T = resize_arr(synapses.T, new_size)
end
function clear!(synapses::GenericSynapses)
  clear!(synapses.frontend)
  fill!(synapses.C, 0f0)
  rand!(synapses.W, 0f0:0.01f0:0.3f0)
  fill!(synapses.T, 0f0)
end
clear!(frontend::GenericFrontend) = clear!(frontend.D)
function Base.show(io::IO, synapses::GenericSynapses)
  println(io, "GenericSynapses ($(synapses.inputSize) => $(synapses.outputSize))")
end
Base.size(synapses::GenericSynapses) = (synapses.outputSize, synapses.inputSize)
function frontend!(gf::GenericFrontend, I)
  gf.D[:] = I
  # TODO: Leverage ID (individual delays)
  I_ = gf.D[:]
  rotate!(gf.D)
  return I_
end

# TODO: Specify input and output types
function _eforward!(scont::CPUContainer{S}, input, output, rewards=nothing) where S<:GenericSynapses
  gs = root(scont)
  condRate, traceRate = gs.condRate, gs.traceRate
  C, W, M, T = gs.C, gs.W, gs.M, gs.T

  I = transient(input).state.F  #@param input[F]
  G = transient(output).state.T #@param output[G]
  F = transient(output).state.F #@param output[F]
  O = transient(output).state.I #@param output[I]

  # Clear outputs
  fill!(O, 0f0)

  # Shift inputs through frontend
  I_ = frontend!(gs.frontend, I)

  # Article: Unsupervised learning of digit recognition using spike-timing-dependent plasticity
  # Authors: Peter U. Diehl and Matthew Cook
  @inbounds for i = axes(W, 2)
    @inbounds @simd for n = axes(W, 1)
      # Convolve weights with input
      C[n,i] += M[n,i] * ((W[n,i] * I_[i]) + (condRate * -C[n,i] * !I_[i]))
      O[n] += W[n,i] * M[n,i] * C[n,i] * I_[i]

      # Update traces
      T[n,i] += I_[i] + (traceRate * -T[n,i] * !I_[i])

      # Learn weights
      W[n,i] += learn!(gs.learn, I_[i], G[n], F[n], W[n,i])
    end
  end

  # Clamp weights
  # TODO: Dispatch on type (or just pull into learn!)
  clamp!(W, 0f0, gs.learn.Wmax)
end
