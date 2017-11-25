### Exports ###

export GenericConfig, GenericState, GenericSynapses

### Types ###

@nodegen mutable struct GenericFrontend{I}
  delayLength::Int

  D::Vector{Array{Bool,I}}
  #ID::Matrix{I} # TODO: Wrong type?
end
GenericFrontend(inputSize, delayLength) = GenericFrontend(delayLength, [zeros(Bool, inputSize) for i = 1:delayLength])
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
    zeros(Float32, outputSize, inputSize)
  )

### Methods ###

function Base.show(io::IO, synapses::GenericSynapses)
  println(io, "GenericSynapses ($(synapses.inputSize) => $(synapses.outputSize))")
end
function frontend!(gf::GenericFrontend, I)
  I_ = gf.D[end]
  @inbounds for d = length(gf.D):-1:1
    gf.D[d] = (d == 1 ? I : gf.D[d-1])
  end
  return I_
end

# TODO: Specify input and output types
function _eforward!(scont::CPUContainer{S}, input, output) where S<:GenericSynapses
  gs = getroot(scont)
  const condRate, traceRate = gs.condRate, gs.traceRate
  const C, W, M, T = gs.C, gs.W, gs.M, gs.T

  I = get(input).state.F  #@param input[F]
  G = get(output).state.T #@param output[G]
  F = get(output).state.F #@param output[F]
  O = get(output).state.I #@param output[I]

  # Clear outputs
  fill!(O, 0f0)

  # Shift inputs through frontend
  I_ = frontend!(gs.frontend, I)

  # Article: Unsupervised learning of digit recognition using spike-timing-dependent plasticity
  # Authors: Peter U. Diehl and Matthew Cook
  @inbounds for i = indices(W, 2)
    @inbounds @simd for n = indices(W, 1)
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
