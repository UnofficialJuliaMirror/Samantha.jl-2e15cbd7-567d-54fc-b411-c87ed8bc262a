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
  outputSize::Int
  conns::Vector{SynapticConnection} = SynapticConnection[]
end
GenericSynapses(outputSize) = GenericSynapses(outputSize=outputSize)

### Edge Patterns ###

#@edgepattern GenericSynapses (:input=>GenericNeurons, :output=>GenericNeurons) sizes->(sizes[:input]*sizes[:output])
@edgepattern GenericSynapses (:input=>ConvNeurons, :reward=>GenericNeurons) sizes->(sizes[:input]*sizes[:reward])

### Methods ###

function addedge!(synapses::GenericSynapses, dstcont, dst, op, conf)
  @assert root(dstcont) isa GenericNeurons
  outputSize = synapses.outputSize
  if op == :input
    data = SynapticInput(dstcont, outputSize, conf)
  elseif op == :output
    # FIXME: Only allow a single output
    data = SynapticOutput(dstcont, conf)
  else
    error("GenericSynapses cannot handle op: $op")
  end
  push!(synapses.conns, SynapticConnection(dst, op, data))
end
deledge!(synapses::GenericSynapses, dst, op) =
  filter!(conn->conn.uuid==dst, synapses.conns)
function resize!(synapses::GenericSynapses, new_size)
  old_size = size(synapses)
  synapses.inputSize = new_size[1]
  synapses.outputSize = new_size[2]
  synapses.C = resize_arr(synapses.C, new_size)
  synapses.W = resize_arr(synapses.W, new_size)
  synapses.M = resize_arr(synapses.M, new_size)
  synapses.T = resize_arr(synapses.T, new_size)
end
function reinit!(synapses::GenericSynapses)
  [reinit!(conn.data) for conn in synapses.conns]
end
reinit!(frontend::GenericFrontend) = clear!(frontend.D)
#function Base.show(io::IO, synapses::GenericSynapses)
#  print(io, "GenericSynapses ($(synapses.inputSize) => $(synapses.outputSize))")
#end
Base.size(synapses::GenericSynapses) = synapses.outputSize
function frontend!(gf::GenericFrontend, I)
  rotate!(gf.D)
  gf.D[:] = I
  return gf.D[gf.ID]
end

#function _eforward!(scont::CPUContainer{S}, input, output, rewards=nothing) where S<:GenericSynapses
function _eforward!(scont::CPUContainer{S}, args) where S<:GenericSynapses
  gs = root(scont)

  # Get output connection
  tgt_conn = first(filter(conn->conn.op==:output, gs.conns))
  tgt_cont = first(filter(arg->arg[2]==tgt_conn.uuid, args))[3]
  tgt_node = root(tgt_cont)

  # TODO: Use dispatch to get these values
  Tout = tgt_node.state.T
  Fout = tgt_node.state.F
  Iout = tgt_node.state.I

  # Clear output neuron inputs
  fill!(Iout, 0.0)

  for src_conn in filter(conn->conn.op!=:output, gs.conns)
    src_cont = first(filter(arg->arg[2]==src_conn.uuid, args))[3]
    src_node = root(src_cont)

    @unpack condRate, traceRate = src_conn.data
    @unpack frontend, learn = src_conn.data
    @unpack C, W, M, T, O = src_conn.data

    # TODO: Use dispatch to get these values
    Fin = src_node.state.F

    # Shift inputs through frontend
    I = frontend!(frontend, Fin)

    # Clear connection outputs
    fill!(O, 0.0)

    @inbounds for i = axes(W, 2)
      @inbounds @simd for n = axes(W, 1)
        # Convolve weights with input
        C[n,i] += M[n,i] * ((W[n,i] * I[i]) + (condRate * -C[n,i] * !I[i]))
        O[n] += W[n,i] * M[n,i] * C[n,i] * I[i]

        # Update traces
        T[n,i] += I[i] + (traceRate * -T[n,i] * !I[i])
      end
    end
    Iout .+= O

    # TODO: Modify learn rate based on rewards
    # FIXME: Remove me
    learnRate = 1.0
    #state = (learnRate=1.0,)
    #mod = conn.data.modulator
    #modulate!(state, node, mod)

    # Article: Unsupervised learning of digit recognition using spike-timing-dependent plasticity
    # Authors: Peter U. Diehl and Matthew Cook
    @inbounds for i = axes(W, 2)
      @inbounds @simd for n = axes(W, 1)
        # Learn weights
        # TODO: Use traces!
        W[n,i] += learnRate * learn!(learn, I[i], Tout[n], Fout[n], W[n,i])
      end
    end

    # Clamp weights
    # TODO: Dispatch on type (or just pull into learn!)
    clamp!(W, zero(eltype(W)), learn.Wmax)
  end
end
