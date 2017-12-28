### Types ###

struct InplaceMutation{T} <: AbstractMutation
  nodetype::T
  params::Dict{NTuple{N,Val} where N, Tuple}
end
function InplaceMutation(nodetype, params)
  symparams = map(kv->Pair(Tuple(map(key->Val{key}(),kv[1])),kv[2]), params)
  newparams = Dict{NTuple{N,Val} where N, Tuple}(symparams)
  InplaceMutation(nodetype, newparams)
end
# TODO: Constructor for "nesting" other InplaceMutations

mutable struct ChangeEdgePatternMutation <: AbstractMutation
  nodetype::Type
  switchProb::Real
end
#=mutable struct InsertNodeMutation <: AbstractMutation
  nodetype::Type
  args::Tuple # TODO: Support for args generation
end
mutable struct DeleteNodeMutation <: AbstractMutation
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

  return agent
end

### Match Checking ###
hasmatches(agent::Agent, mutation::InplaceMutation) =
  any(node->typeof(transient(node))<:mutation.nodetype, values(agent.nodes))
hasmatches(agent::Agent, mutation::ChangeEdgePatternMutation) = true
# FIXME: Enable once tests pass
#  any(node->typeof(transient(node))<:mutation.nodetype, values(agent.nodes))
#=function hasmatches(agent::Agent, mutation::InsertNodeMutation)
  for typ in values(mutation.pattern)
    if length(filter(id->(typeof(transient(agent.nodes[id]))==typ), agent.nodes)) == 0
      return false
    end
  end
  return true
end=#

### Mutations ###

function mutate!(agent::Agent, mutation::InplaceMutation)
  # Pick random matching node
  nodes = filter(node->typeof(node[2])<:mutation.nodetype, [(id,transient(node)) for (id,node) in agent.nodes])
  id, node = rand(nodes)
  for (path,(prob,gen)) in mutation.params
    # TODO: Pass down result of bounds(node, path)
    node[path] = mutate!(node[path], prob, gen)
  end
end
function mutate!(agent::Agent, mutation::ChangeEdgePatternMutation)
  # Pick random matching node
  nodes = filter(node->typeof(node[2])<:mutation.nodetype, [(idx,transient(node)) for (idx,node) in agent.nodes])
  idx, node = rand(nodes)

  # Pick a random edge pattern
  valid_patterns = filter((T,pattern)->typeof(node)<:T, EDGE_PATTERNS)
  new_pattern, sizefunc = rand(rand(valid_patterns)[2])
  info("New Pattern:")
  info(typeof(new_pattern))
  info(new_pattern)

  # Get the old edge pattern
  old_pattern = Dict(map(edge->edge[3]=>typeof(root(agent.nodes[edge[2]])), filter(edge->edge[1]==idx, agent.edges)))
  info("Old Pattern:")
  info(typeof(old_pattern))
  info(old_pattern)

  # Determine minimum required changes
  req_changes = Pair{Symbol,Symbol}[]
  for (op,T) in merge(old_pattern, new_pattern)
    if haskey(new_pattern, op) && haskey(old_pattern, op)
      # Check types
      if !(old_pattern[op] <: new_pattern[op])
        # Need to switch
        push!(req_changes, :switch => op)
      end
    elseif haskey(new_pattern, op) && !haskey(old_pattern, op)
      # Need to insert
      push!(req_changes, :insert => op)
    elseif !haskey(new_pattern, op) && haskey(old_pattern, op)
      # Need to delete
      push!(req_changes, :delete => op)
    end
  end
  info(req_changes)

  # Apply minimum required changes
  old_edgeset = Dict(map(pat->pat[1]=>filter(edge->(edge[1]==idx)&&(edge[3]==pat[1]), agent.edges)[1][2], old_pattern))
  info("Old Edgeset:")
  info(old_edgeset)
  new_edgeset = Dict{Symbol,String}()
  for (change,op) in req_changes
    if change == :switch
      deledge!(agent, idx, old_edgeset[op], op)
      if rand() < mutation.switchProb && length(map(node->typeof(root(node))<:new_pattern[op], values(agent.nodes))) > 0
        # Use an existing node instead of creating a new one
        existing_nodes = filter((existing_idx,existing_node)->typeof(root(existing_node))<:new_pattern[op], agent.nodes)
        addedge!(agent, idx, rand(existing_nodes)[2], op)
      else
        new_size = sizefunc(Dict(map((old_op,old_idx)->(old_op=>size(root(agent.nodes[old_idx]))), old_edgeset)))
        new_node = randnode(new_pattern[op], new_size)
        new_idx = addnode!(agent, new_node)
        addedge!(agent, idx, new_idx, op)
      end
    elseif change == :insert
      new_size = sizefunc(Dict(map(old_edgepair->(old_edgepair[1]=>size(root(agent.nodes[old_edgepair[2]]))), old_edgeset)))
      new_node = randnode(new_pattern[op], new_size)
      new_idx = addnode!(agent, new_node)
      addedge!(agent, idx, new_idx, op)
    elseif change == :delete
      deledge!(agent, idx, old_edgeset[op], op)
    end
  end
  # FIXME: Apply extra changes as random walk within new pattern
  # FIXME: Prune disconnected nodes
  error("Not implemented")
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
