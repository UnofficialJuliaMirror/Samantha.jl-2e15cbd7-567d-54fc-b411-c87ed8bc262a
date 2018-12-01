### Exports ###

export Layer, GenericLayer

### Types ###

struct Layer{S,N} <: AbstractNode
  synapses::S
  neurons::N
end

const GenericLayer = Layer{GenericSynapses,GenericNeurons}
function GenericLayer(sz::Int)
  Layer(GenericSynapses(sz), GenericNeurons(sz))
end

mutable struct LayerGlobalState
  # FIXME: Put useful stuff in here
end

mutable struct LayerLocalState
  # FIXME: Put useful stuff in here
end

### Methods ###

addedge!(layer::Layer, dstcont, dst, op, conf) =
  addedge!(layer.synapses, dstcont, dst, op, conf)
deledge!(layer::Layer, dst, op) =
  deledge!(layer.synapses, dst, op)

function reinit!(layer::Layer)
  reinit!(layer.synapses)
  reinit!(layer.neurons)
end

Base.size(layer::Layer) = size(layer.neurons)

function eforward!(lcont::CPUContainer{Layer{S,N}}, args) where {S,N}
  layer = root(lcont)

  # TODO: Sort conns and args by UUID for speed?
  conns = map(conn->(
    conn,
    findfirst(arg->arg[2]==conn.uuid, args),
    LayerLocalState()
  ), connections(layer.synapses))

  # Initialize global state
  global_state = LayerGlobalState()

  # Get inputs and shift frontends
  for conn in conns
    inputs = conn[]
    shift_frontend!(conn)
  end

  # Early modulation
  for conn in conns
    early_modulate!(conn, global_state)
  end

  # Calculate outputs
  for conn in conns
    calculate_outputs!(conn)
  end

  # Late modulation
  for conn in conns
    late_modulate!(conn, global_state)
  end

  # Cycle neurons
  for idx in 1:size(layer.neurons)
    layer.neurons[idx] = layer.synapses[idx]
  end
  cycle_neurons!(layer.neurons)

  # TODO: Learning modulation?

  # Learn weights
  for conn in conns
    learn_weights!(conn, tgt_conns)
  end
end

const ConnWrapper = Tuple{SynapticConnection{D1}, Container{D2}, LayerLocalState} where {D1,D2}

shift_frontend!(conn::ConnWrapper) =
  shift_frontend!(conn[1], conn[2])
