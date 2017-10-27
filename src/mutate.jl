### Types ###

struct InplaceMutation{T} <: AbstractMutation
  nodetype::T
  params::Dict{NTuple{N,Val} where N, Tuple}
end
InplaceMutation(nodetype, params) =
  InplaceMutation(nodetype, Dict{NTuple{N,Val} where N, Tuple}(map(kv->Pair(Tuple(map(key->Val{key}(),kv[1])),kv[2]), params)))
# TODO: Constructor for "nesting" other InplaceMutations

#=mutable struct InsertNodeMutation <: AbstractMutation
  nodetype::Type
  args::Tuple # TODO: Support for args generation
end
mutable struct DeleteNodeMutation <: AbstractMutation
  nodetype::Type
  pattern::Dict{Symbol,Type} # TODO: Support multiple nodes for a single operator
end
mutable struct ChangeEdgePatternMutation <: AbstractMutation
  nodetype::Type
  pattern::Dict{Symbol,Type} # TODO: Support multiple nodes for a single operator
end=#

struct MutationProfile
  mutations::Vector{AbstractMutation}
  # TODO: Mask
end
MutationProfile() = MutationProfile(AbstractMutation[])

# TODO: More than one mutation per cycle?
function mutate!(agent::Agent, profile::MutationProfile)
  # Determine which mutations are possible
  mutations = []
  for m in profile.mutations
    if hasmatches(agent, m)
      push!(mutations, m)
    end
  end

  if length(mutations) > 0
    # Pick one mutation randomly and apply it
    mutation = mutations[rand(eachindex(mutations))]
    mutate!(agent, mutation)
  end
end

### Match Checking ###
hasmatches(agent::Agent, mutation::InplaceMutation) =
  any(node->typeof(Samantha.get(node))<:mutation.nodetype, values(agent.nodes))
#=function hasmatches(agent::Agent, mutation::InsertNodeMutation)
  for typ in values(mutation.pattern)
    if length(filter(id->(typeof(get(agent.nodes[id]))==typ), agent.nodes)) == 0
      return false
    end
  end
  return true
end=#
# TODO: Other hasmatches

### Mutations ###

function mutate!(agent::Agent, mutation::InplaceMutation)
  # Pick random matching node
  nodes = filter(node->typeof(node[2])<:mutation.nodetype, [(id,get(node)) for (id,node) in agent.nodes])
  id, node = nodes[rand(1:length(nodes))]
  for (path,(prob,gen)) in mutation.params
    # TODO: Pass down result of bounds(node, path)
    node[path] = mutate!(node[path], prob, gen)
  end
end
#=function mutate!(agent::Agent, mutation::InsertNodeMutation)
  # Create node and attach to agent
  # FIXME: Pick random matching nodes
  # FIXME: Compute size from nodes
  node = mutation.nodetype(mutations.args...)
  addnode!(agent, node)
  # FIXME: Create edges
end=#

# Determines whether or not to mutate a parameter
mutate!(val, prob::Real, gen) = (prob >= rand() ? mutate!(val, gen) : val)

# Default mutations when no generator is specified
# TODO: Respect bounds()
mutate!(num::N, gen::Void) where N<:Number = rand(N)
#=function mutate!(arr::AbstractArray, gen::Void)
  for i in eachindex(arr)
    arr[i] = mutate!(arr[i], gen)
  end
  return arr
end=#
