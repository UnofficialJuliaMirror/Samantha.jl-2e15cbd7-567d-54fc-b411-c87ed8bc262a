export AbstractMutation, AgentMutation, NodeMutation, EdgeMutation
export InplaceMutation, ChangeEdgePatternMutation

### Types ###

abstract type AbstractMutation end
abstract type AgentMutation <: AbstractMutation end
abstract type NodeMutation <: AbstractMutation end
abstract type EdgeMutation <: AbstractMutation end

struct InplaceMutation{T} <: NodeMutation
  nodetype::Type{T}
  params::Dict{NTuple{N,Val} where N, Tuple}
end
# FIXME: Allow params to have key of Symbol
function InplaceMutation(nodetype, params)
  symparams = Dict{NTuple{N,Val} where N, Tuple}((Pair(map(key->Val(key),kv[1]),kv[2]) for kv in params))
  InplaceMutation(nodetype, symparams)
end
# TODO: Constructor for "nesting" other InplaceMutations

mutable struct ChangeEdgePatternMutation <: AgentMutation
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

const MutationProfile = Vector{AbstractMutation}

# TODO: More than one mutation per cycle? Or maybe try to apply ALL mutations at once???
function mutate!(profile::MutationProfile, agent::Agent)
  # Determine which mutations are possible
  mutations = []
  for m in profile
    if hasmatches(m, agent)
      push!(mutations, m)
    end
  end

  if length(mutations) > 0
    # Pick one mutation randomly and apply it
    mutation = mutations[rand(eachindex(mutations))]
    mutate!(mutation, agent)
  end

  return agent
end

### Match Checking ###
hasmatches(mutation::InplaceMutation, agent::Agent) =
  any(node->typeof(transient(node))<:mutation.nodetype, values(agent.nodes))
hasmatches(mutation::ChangeEdgePatternMutation, agent::Agent) = true
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

function mutate!(mutation::InplaceMutation, agent::Agent)
  # Pick random matching node
  nodes = filter(node->typeof(node[2])<:mutation.nodetype, [(id,transient(node)) for (id,node) in agent.nodes])
  id, node = rand(nodes)
  for (path,(prob,gen)) in mutation.params
    # TODO: Pass down result of bounds(node, path)
    node[path] = mutate!(node[path], prob, gen)
  end
end
function mutate!(mutation::ChangeEdgePatternMutation, agent::Agent)
  # Pick random matching node
  nodes = filter(node->typeof(node[2])<:mutation.nodetype, [(idx,transient(node)) for (idx,node) in agent.nodes])
  idx, node = rand(nodes)

  # Pick a random edge pattern
  valid_patterns = filter((T,pattern)->typeof(node)<:T, EDGE_PATTERNS)
  new_pattern, sizefunc = rand(rand(valid_patterns)[2])
  @info "New Pattern:"
  @info typeof(new_pattern)
  @info new_pattern

  # Get the old edge pattern
  old_pattern = Dict(map(edge->edge[3]=>typeof(root(agent.nodes[edge[2]])), filter(edge->edge[1]==idx, agent.edges)))
  @info "Old Pattern:"
  @info typeof(old_pattern)
  @info old_pattern

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
  @info req_changes

  # Apply minimum required changes
  old_edgeset = Dict(map(pat->pat[1]=>filter(edge->(edge[1]==idx)&&(edge[3]==pat[1]), agent.edges)[1][2], old_pattern))
  @info "Old Edgeset:"
  @info old_edgeset
  #new_edgeset = Dict{Symbol,String}()
  for (change,op) in req_changes
    if change == :switch
      deledge!(agent, idx, old_edgeset[op], op)
      if rand() < mutation.switchProb && length(map(existing_node->typeof(root(existing_node))<:new_pattern[op], values(agent.nodes))) > 0
        # Use an existing node instead of creating a new one
        existing_nodes = filter((existing_idx,existing_node)->typeof(root(existing_node))<:new_pattern[op], agent.nodes)
        # TODO: Delete existing node's old edges?
        addedge!(agent, idx, rand(existing_nodes)[2], op)
      else
        new_node = randnode(new_pattern[op])
        new_idx = addnode!(agent, new_node)
        addedge!(agent, idx, new_idx, op)
      end
    elseif change == :insert
      # FIXME: Also give the option to use an existing node
      new_node = randnode(new_pattern[op])
      new_idx = addnode!(agent, new_node)
      addedge!(agent, idx, new_idx, op)
    elseif change == :delete
      deledge!(agent, idx, old_edgeset[op], op)
    end
  end

  # FIXME: Apply extra changes as random walk within new pattern
  # FIXME: Reshape src node if necessary
  #new_size = sizefunc(Dict(map((old_op,old_idx)->(old_op=>size(root(agent.nodes[old_idx]))), old_edgeset)))
  new_size = sizefunc(Dict(map(old_edgepair->(old_edgepair[1]=>size(root(agent.nodes[old_edgepair[2]]))), old_edgeset)))
  if size(node) != new_size
    agent.nodes[idx] = resize!(node, new_size)
  end

  # Prune disconnected nodes
  prune!(agent)
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

function mutate!(arr::AbstractArray, gen)
  for i in eachindex(arr)
    arr[i] = mutate!(arr[i], gen)
  end
  return arr
end

### Default Generators ###

# TODO: Respect bounds()
mutate!(num::N, gen::Nothing) where N<:Number = rand(N)
mutate!(num::N, gen::Vector) where N = convert(N, rand(gen))
