export Agent
export load, store!, sync!, addnode!, delnode!, addedge!, deledge!, merge, merge!, barrier
export clone, mutate!
export activate!, deactivate!
export relocate!, store!, sync!, addnode!, delnode!, addedge!, deledge!, merge, merge!, barrier
export mutate!
export run_edges!, run_nodes!, run!

mutable struct AgentRunTable
  worklists::Dict{Int, Vector{String}}
  locklist::Dict{String, Bool}
  lock::Threads.TatasLock
end
AgentRunTable() = AgentRunTable(Dict{Int,Vector{String}}([(idx, String[]) for idx in 1:Threads.nthreads()]), Dict{String,Bool}(), Threads.TatasLock())
load(ldbl::Loadable, name::String, ::Type{AgentRunTable}) = AgentRunTable()
store!(ldbl::Loadable, name::String, data::AgentRunTable) = ()

@nodegen mutable struct Agent
  nodes::Dict{String, AbstractContainer}
  edges::Vector{Tuple{String, String, Symbol}}
  layout::Dict{String, Union{Dict, String}}
  groups::Dict{String, Vector{String}}
  rt::AgentRunTable
end
Agent() = Agent(Dict{String,AbstractContainer}(), Tuple{String,String,Symbol}[], Dict{String,Union{Dict,String}}(), Dict{String,Vector{String}}(), AgentRunTable())

# Retrieve layout item
getindex(agent::Agent, idx::String) = agent.layout[idx]

# Set layout item (shorthand for merge!())
setindex!(agent1::Agent, agent2::Agent, idx::String) = merge!(agent1, agent2; name=idx)

# Adds a node, with the option of a top-level name
function addnode!(agent::Agent, node::AbstractNode; name::String="")
  id = randstring(16)
  if name != ""
    @assert !haskey(agent.layout, name) "Name $name already exists in layout"
    agent.layout[name] = id
  end
  agent.nodes[id] = CPUContainer(node)
  return id
end

# Deletes a node
# TODO: Delete associated edges
function delnode!(agent::Agent, id::String)
  node = agent.nodes[id]
  Base.delete!(agent.nodes, id)
end

# Adds an edge connection from a source node to a target node with a specified operation
addedge!(agent::Agent, src::String, dst::String, op::Symbol) = push!(agent.edges, (src, dst, op))
function addedge!(agent::Agent, src::String, pairs::Tuple)
  for pair in pairs
    addedge!(agent, src, pair[1], pair[2])
  end
end

# Deletes an edge
function deledge!(agent::Agent, src::String, dst::String, op::Symbol)
  edges = findall(edge->(edge[1]==src&&edge[2]==dst&&edge[3]==op), agent.edges)
  @assert length(edges) != 0 "No such edge found with src: $src, dst: $dst, op: $op"
  @assert length(edges) < 2 "Multiple matching edges returned"
  deleteat!(agent.edges, edges[1])
end

# Returns the union of two agents
function merge(agent1::Agent, agent2::Agent)
  agent3 = Agent()
  agent3.nodes = Base.merge(agent1.nodes, agent2.nodes)
  agent3.edges = vcat(agent1.edges, agent2.edges)
  return agent3
end

# Merges agent2 into agent1, with the option of making agent2 a sub-layout of agent1
function merge!(agent1::Agent, agent2::Agent; name::String="")
  Base.merge!(agent1.nodes, agent2.nodes)
  agent1.edges = vcat(agent1.edges, agent2.edges)
  if name != ""
    agent1.layout[name] = agent2.layout
  else
    Base.merge!(agent1.layout, agent2.layout)
  end
  return agent1
end

# Sets a barrier on all agent nodes
function barrier(agent::Agent)
  for node in values(agent.nodes)
    barrier(node)
  end
end

# Clones an agent in its entirety
function clone(agent::Agent)
  cloneAgent = Agent()
  for objIdx in keys(agent.nodes)
    cloneAgent.nodes[objIdx] = clone(agent.nodes[objIdx])
  end
  cloneAgent.edges = copy(agent.edges)
  return cloneAgent
end

# Activates a group
# TODO: madvise?
function activate!(agent::Agent, group::String)
  for idx in agent.groups[group]
    cont = agent.nodes[idx]
    if cont isa InactiveContainer
      agent.nodes[idx] = CPUContainer(transient(cont))
    end
  end
end

# Deactivates a group
# FIXME: Sync transient to root before deactivating
# TODO: madvise?
function deactivate!(agent::Agent, group::String)
  for idx in agent.groups[group]
    cont = agent.nodes[idx]
    if !(cont isa InactiveContainer)
      agent.nodes[idx] = InactiveContainer(transient(cont))
    end
  end
end

# Mutates an agent with probability p for each mutatable parameter
#=function mutate!(agent::Agent, p::Real)
  for node in values(agent.nodes)
    mutate!(node, p)
  end
end=#

# Clears any transient data in an agent (such as learned weights or temporary values)
function clear!(agent::Agent)
  for node in values(agent.nodes)
    clear!(root(node))
  end
end

# Prints a short representation of the agent
# TODO: Use colors if enabled
function Base.show(io::IO, agent::Agent)
  println(io, "Agent:")
  println(io, "  $(length(agent.nodes)) nodes")
  println(io, "  $(length(agent.edges)) edges")
  println(io, "  $(length(agent.groups)) groups")
end

# Prints a long representation of the agent
# TODO: Use colors if enabled
# TODO: Optionally elaborate nodes, edges, groups?
function Base.showall(io::IO, agent::Agent)
  Base.show(io, agent)
  println(io, "  Layout:")
  for (name,value) in agent.layout
    # TODO: Recursively descend into value if possible
    println(io, "    $name: $value")
  end
end

# Runs all nodes for one iteration
function run_nodes!(agent::Agent)
  nodes = collect(values(agent.nodes))
  if canthread()
    Threads.@threads for node in nodes
      nupdate!(node)
    end
  else
    for node in nodes
      nupdate!(node)
    end
  end
end

# Runs all edge-connected nodes for one iteration
function run_edges!(agent::Agent)
  # Construct edge sets
  # TODO: Support multiple nodes with the same op
  edges = Dict{String, Vector{Tuple{Symbol,AbstractContainer}}}()
  for edgeObj in agent.edges
    name = edgeObj[1]
    entry = (edgeObj[3], agent.nodes[edgeObj[2]])
    if haskey(edges, name)
      push!(edges[name], entry)
    else
      edges[name] = Tuple{Symbol,AbstractContainer}[entry]
    end
  end

  # Mark all edges as ready-to-run
  # Current algorithm: Round-robin
  # TODO: Use more cache-friendly algorithm
  tidx = 1
  maxTidx = Threads.nthreads()
  for edgeName in keys(edges)
    push!(agent.rt.worklists[tidx], edgeName)
    tidx = (tidx >= maxTidx ? 1 : tidx + 1)
  end
  
  # Run edges
  if canthread()
    Threads.@threads for tidx in 1:Threads.nthreads()
      # Wait for lock
      lock(agent.rt.lock)

      # Check all edgesets
      completed = nothing
      for edgeIdx in agent.rt.worklists[tidx]
        # Check if full edgeset is available
        nodes = map(edgeTuple->edgeTuple[2], filter(edgeTuple->edgeTuple[1]==edgeIdx, agent.edges))
        if (!haskey(agent.rt.locklist,edgeIdx)||agent.rt.locklist[edgeIdx] == false) &&
          all(node->(!haskey(agent.rt.locklist,node)||agent.rt.locklist[node]==false), nodes)
          # Add edgeset to locklist
          agent.rt.locklist[edgeIdx] = true
          for node in nodes
            agent.rt.locklist[node] = true
          end
          unlock(agent.rt.lock)

          # Run edgeset
          node = agent.nodes[edgeIdx]
          edgeset = Tuple{Symbol,AbstractContainer}[edges[edgeIdx]...]
          eforward!(node, edgeset)

          # Mark edgeset as done
          completed = edgeIdx

          # Clear edgeset from locklist
          lock(agent.rt.lock)
          agent.rt.locklist[edgeIdx] = false
          for node in nodes
            agent.rt.locklist[node] = false
          end
        end
      end
      if completed != nothing
        idx = findfirst(edgeIdx->edgeIdx==completed, agent.rt.worklists[tidx])
        deleteat!(agent.rt.worklists[tidx], idx)
      end

      # Pass to next thread and wait
      unlock(agent.rt.lock)
    end
  else
    for edgeName in keys(edges)
      eforward!(agent.nodes[edgeName], edges[edgeName])
    end
  end
end

# Runs agent for one iteration
function run!(agent::Agent)
  # Forward pass on each node
  run_nodes!(agent)

  # Forward pass on edge-connected nodes
  run_edges!(agent)
end
