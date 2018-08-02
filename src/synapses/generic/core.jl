### Exports ###

export GenericConfig, GenericState, GenericSynapses

### Types ###

mutable struct GenericFrontend
  delayLength::Int

  D::RingBuffer{Bool}
  ID::Vector{Int}
end
GenericFrontend(inputSize::Int, delayLength::Int, delayIndices=(delayLength-1)*ones(inputSize)) =
  GenericFrontend(delayLength, RingBuffer(Bool, inputSize, delayLength), delayIndices)

@with_kw mutable struct GenericSynapses <: AbstractSynapses
  conns::Vector{SynapticConnection} = SynapticConnection[]
end

### Edge Patterns ###

#@edgepattern GenericSynapses (:input=>GenericNeurons, :output=>GenericNeurons) sizes->(sizes[:input]*sizes[:output])
@edgepattern GenericSynapses (:input=>ConvNeurons, :reward=>GenericNeurons) sizes->(sizes[:input]*sizes[:reward])

### Methods ###

function addedge!(synapses::GenericSynapses, dstcont, dst, op, conf)
  @assert root(dstcont) isa GenericNeurons
  if op == :input
    data = SynapticInput(dstcont, conf)
  elseif op == :output
    data = SynapticOutput(dstcont, conf)
  else
    error("GenericSynapses cannot handle op: $op")
  end
  push!(synapses.conns, SynapticConnection(dst, op, data))
end
deledge!(synapses::GenericSynapses, dst, op) =
  filter!(conn->conn.src==dst, synapses.conns)
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
  rand!(synapses.W, 0f0:0.01f0:1.0f0)
  fill!(synapses.T, 0f0)
end
clear!(frontend::GenericFrontend) = clear!(frontend.D)
function Base.show(io::IO, synapses::GenericSynapses)
  print(io, "GenericSynapses ($(synapses.inputSize) => $(synapses.outputSize))")
end
Base.size(synapses::GenericSynapses) = (synapses.outputSize, synapses.inputSize)
function frontend!(gf::GenericFrontend, I)
  rotate!(gf.D)
  gf.D[:] = I
  return gf.D[gf.ID]
end

#function _eforward!(scont::CPUContainer{S}, input, output, rewards=nothing) where S<:GenericSynapses
function _eforward!(scont::CPUContainer{S}, args) where S<:GenericSynapses
  gs = root(scont)

  #O_sum = similar(
  for conn in filter(conn->conn.op!=:output, gs.conns)
    tgt_cont = first(filter(arg->arg[2]==conn.uuid, args))[3]
    tgt_node = root(tgt_cont)
    @unpack condRate, traceRate = conn.data
    @unpack frontend, learn = conn.data
    @unpack C, W, M, T, O = conn.data

    # TODO: Use dispatch to get these values
    I = transient(tgt_node).state.F  #@param input[F]

    # Shift inputs through frontend
    I_ = frontend!(frontend, I)

    @inbounds for i = axes(W, 2)
      @inbounds @simd for n = axes(W, 1)
        # Convolve weights with input
        C[n,i] += M[n,i] * ((W[n,i] * I_[i]) + (condRate * -C[n,i] * !I_[i]))
        O[n] += W[n,i] * M[n,i] * C[n,i] * I_[i]

        # Update traces
        T[n,i] += I_[i] + (traceRate * -T[n,i] * !I_[i])
      end
    end

    # Modify learn rate based on rewards
    state = (learnRate=1.0,)
    mod = conn.data.modulator
    modulate!(state, node, mod)

    # Article: Unsupervised learning of digit recognition using spike-timing-dependent plasticity
    # Authors: Peter U. Diehl and Matthew Cook
    @inbounds for i = axes(W, 2)
      @inbounds @simd for n = axes(W, 1)
        # Learn weights
        # TODO: Use traces!
        W[n,i] += learnRate * learn!(gs.learn, I_[i], G[n], F[n], W[n,i])
      end
    end

    # Clamp weights
    # TODO: Dispatch on type (or just pull into learn!)
    clamp!.(W, zero(eltype(W)), gs.learn.Wmax)
  end

  conn = first(filter(conn->conn.op==:output, gs.conns))
  tgt_cont = first(filter(arg->arg[2]==conn.uuid, args))[3]
  tgt_node = root(tgt_cont)

  # TODO: Use dispatch to get these values
  G = transient(tgt_node).state.T #@param output[G]
  F = transient(tgt_node).state.F #@param output[F]
  O = transient(tgt_node).state.I #@param output[I]
end
