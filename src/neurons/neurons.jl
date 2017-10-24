### Imports ###

import Base: setindex!, getindex

### Exports ###

export NConfig, NState, Neurons
export params, show, store!, sync!
export size, accum!, nforward!, gradients, inputs, outputs, setindex!, getindex, nupdate!, mutate!

### Types ###

@nodegen mutable struct NConfig{S}
  size::S
  a::Float32
  b::Float32
  c::Float32
  d::Float32
  thresh::Float32
  traceRate::Float32
  boostRate::Float32
end
@nodegen mutable struct NState{RT<:AbstractArray{Float32}, BT<:AbstractArray{Bool}}
  V::RT
  U::RT
  I::RT
  F::BT
  T::RT
  B::RT
end
@nodegen mutable struct Neurons{C<:NConfig, S<:NState} <: AbstractNeurons
  conf::C
  state::S
end

NCPUCont{C,S} = CPUContainer{Neurons{C,S}}

### Methods ###

size(neurons::Neurons) = neurons.conf.size

# TODO: Fill in the rest of the inactive methods
#inputs(neurons::Neurons) = neurons.state.I
#inputs{C,S}(ncont::NCPUCont{C,S}) = ncont.active ? get(ncont).state.I : ZeroArray(get(ncont).state.I)
#setindex!(neurons::Neurons, value, idx...) = setindex!(neurons.state.I, value, idx...)

#outputs(neurons::Neurons) = neurons.state.F
#outputs{C,S}(ncont::NCPUCont{C,S}) = ncont.active ? get(ncont).state.F : ZeroArray(get(ncont).state.F)
#getindex(neurons::Neurons, idx...) = getindex(neurons.state.F, idx...)

gradients(neurons::Neurons) = neurons.state.T
gradients{C,S}(ncont::NCPUCont{C,S}) = get(ncont).state.T

@inline function _nforward!(i, a, b, c, d, thresh, traceRate, boostRate, V, U, I, F, T, B)
  # Update V and U
  V[i] += 0.5f0 * ((0.04f0 * (V[i] * V[i])) + (5f0 * V[i]) + 140f0 - U[i] + I[i])
  V[i] += 0.5f0 * ((0.04f0 * (V[i] * V[i])) + (5f0 * V[i]) + 140f0 - U[i] + I[i])
  U[i] += a * ((b * V[i]) - U[i])
  #V[i] += -4f0 * (B[i] - 0.8f0)

  # Spike and reset
  F[i] = (V[i] >= thresh)
  # TODO: F[i] = (V[i] >= thresh + θ)
  V[i] += (F[i] * (c - V[i]))
  U[i] += F[i] * d

  # TODO: Update θ
  # θ += F[i] + (θRate * -θ * F[i])

  # Update traces
  T[i] += F[i] + (traceRate * -T[i] * !F[i])
  #local traceT = fasttanh(T[i])
  #T[i] += traceRate * (((.75f0 - traceT) * F[i]) + ((0.00f0 - traceT) * !F[i]))

  # Update boosts
  # B[i] += boostRate * (T[i] - B[i])

  # Clear inputs
  I[i] = 0f0
end

function nforward!(a, b, c, d, thresh, traceRate, boostRate, V, U, I, F, T, B)
  if canthread() && length(V) > 2^20
    Threads.@threads for i = eachindex(V)
      _nforward!(i, a, b, c, d, thresh, traceRate, boostRate, V, U, I, F, T, B)
    end
  else
    @inbounds @simd for i = eachindex(V)
      _nforward!(i, a, b, c, d, thresh, traceRate, boostRate, V, U, I, F, T, B)
    end
  end
end
function nforward!(neurons::Neurons)
  local conf = neurons.conf
  local state = neurons.state
  nforward!(conf.a, conf.b, conf.c, conf.d, conf.thresh, conf.traceRate, conf.boostRate, state.V, state.U, state.I, state.F, state.T, state.B)
end
nforward!{C,S}(ncont::NCPUCont{C,S}) = nforward!(get(ncont))

function nupdate!{C,S}(ncont::NCPUCont{C,S})
  nforward!(ncont)
end



function nupdate!(neurons::Neurons)
  @unwrap neurons conf state
  @unwrap conf a b c d thresh
  @unwrap state V U I F T B
  @threadoption for i = eachindex(neurons[:V])
    # Update V and U
    V[i] += 0.5f0 * ((0.04f0 * (V[i] * V[i])) + (5f0 * V[i]) + 140f0 - U[i] + I[i])
    V[i] += 0.5f0 * ((0.04f0 * (V[i] * V[i])) + (5f0 * V[i]) + 140f0 - U[i] + I[i])
    U[i] += a * ((b * V[i]) - U[i])
    #V[i] += -4f0 * (B[i] - 0.8f0)

    # Spike and reset
    F[i] = (V[i] >= thresh)
    # TODO: F[i] = (V[i] >= thresh + θ)
    V[i] += (F[i] * (c - V[i]))
    U[i] += F[i] * d

    # TODO: Update θ
    # θ += F[i] + (θRate * -θ * !F[i])

    # Update traces
    T[i] += F[i] + (traceRate * -T[i] * !F[i])
    #local traceT = fasttanh(T[i])
    #T[i] += traceRate * (((.75f0 - traceT) * F[i]) + ((0.00f0 - traceT) * !F[i]))

    # Update boosts
    # B[i] += boostRate * (T[i] - B[i])

    # Clear inputs
    I[i] = 0f0  
  end
end



#=
function mutate!(neurons::Neurons, p::Real)
  conf = neurons.conf
  conf.a = (rand() < p ? rand(0.02f0:0.01f0:0.1f0) : conf.a)
  conf.b = (rand() < p ? rand(0.1f0:0.01f0:0.3f0) : conf.b)
  conf.c = (rand() < p ? rand(-70f0:1f0:50f0) : conf.c)
  conf.d = (rand() < p ? rand(0.01f0:0.01f0:8f0) : conf.d)
  conf.thresh = (rand() < p ? rand(10f0:1f0:50f0) : conf.thresh)
  conf.traceRate = (rand() < p ? rand(0.01f0:0.01f0:1f0) : conf.traceRate)
end=#

### Includes ###

include("generic/core.jl")
include("conv/core.jl")
