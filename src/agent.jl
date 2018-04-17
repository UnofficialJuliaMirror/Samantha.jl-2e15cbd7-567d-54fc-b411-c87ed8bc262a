export Agent
export sync!, addnode!, delnode!, addedge!, deledge!, merge, merge!, barrier
export activate!, deactivate!
export relocate!, store!, sync!, addnode!, delnode!, addedge!, deledge!, merge, merge!, barrier
export run_edges!, run_nodes!, run!

@nodegen mutable struct Agent
  nodes::Dict{String, AbstractContainer}
  edges::Vector{Tuple{String, String, Symbol}}
end
Agent() = Agent(Dict{String,AbstractContainer}(), Tuple{String,String,Symbol}[])

# Adds a node
function addnode!(agent::Agent, node::AbstractNode)
  id = randstring(16)
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
function addedge!(agent::Agent, src::String, dst::String, op::Symbol)
  addedge!(agent.nodes[src], agent.nodes[dst], dst, op)
  push!(agent.edges, (src, dst, op))
end
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
  deledge!(agent.nodes[src], dst, op)
end
deledge!(agent::Agent, edge::Tuple{String,String,Symbol}) = delete!(agent.edges, edge)

# Returns the union of two agents
function merge(agent1::Agent, agent2::Agent)
  agent3 = Agent()
  agent3.nodes = Base.merge(agent1.nodes, agent2.nodes)
  agent3.edges = vcat(agent1.edges, agent2.edges)
  return agent3
end

# Merges agent2 into agent1
function merge!(agent1::Agent, agent2::Agent)
  Base.merge!(agent1.nodes, agent2.nodes)
  agent1.edges = vcat(agent1.edges, agent2.edges)
  return agent1
end

# Sets a barrier on all agent nodes
function barrier(agent::Agent)
  for node in values(agent.nodes)
    barrier(node)
  end
end

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
end

# Prints a long representation of the agent
# TODO: Use colors if enabled
# TODO: Optionally elaborate nodes, edges, groups?
function Base.showall(io::IO, agent::Agent)
  Base.show(io, agent)
end

# Runs all nodes for one iteration
function run_nodes!(agent::Agent)
  nodes = collect(values(agent.nodes))
  for node in nodes
    nupdate!(node)
  end
end

# Runs all edge-connected nodes for one iteration
function run_edges!(agent::Agent)
  # Construct edge sets
  # TODO: Support multiple nodes with the same op
  edges = Dict{String, Vector{Tuple{Symbol,String,AbstractContainer}}}()
  for edgeObj in agent.edges
    name = edgeObj[1]
    entry = (edgeObj[3], edgeObj[2], agent.nodes[edgeObj[2]])
    if haskey(edges, name)
      push!(edges[name], entry)
    else
      edges[name] = Tuple{Symbol,String,AbstractContainer}[entry]
    end
  end
  
  # Run edges
  for edgeName in keys(edges)
    eforward!(agent.nodes[edgeName], edges[edgeName])
  end
end

# Runs agent for one iteration
function run!(agent::Agent)
  # Forward pass on each node
  run_nodes!(agent)

  # Forward pass on edge-connected nodes
  run_edges!(agent)
end
