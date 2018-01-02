struct RecombinationProfile
  recombinations::Vector{AbstractRecombination}
end
RecombinationProfile() = RecombinationProfile(AbstractRecombination[])

struct CheapRecombination <: AbstractRecombination
  nodeAddProb::Real
  edgeAddProb::Real
end

function recombine(profile::RecombinationProfile, agent1::Agent, agent2::Agent)
  agent3 = Agent()
  for recombination in profile.recombinations
    recombine!(recombination, agent1, agent2, agent3)
  end
  return agent3
end

function recombine!(cr::CheapRecombination, agent1::Agent, agent2::Agent, agent3::Agent)
  for (idx1,node1) in agent1.nodes
    if haskey(agent2.nodes, idx1) && typeof(root(node1)) === typeof(root(agent2.nodes[idx1]))
      # Copy all exactly matching nodes
      agent3.nodes[idx1] = deepcopy(rand() < 0.5 ? node1 : agent2.nodes[idx1])
    else
      # Optionally add node1
      if rand() < cr.nodeAddProb
        agent3.nodes[idx1] = deepcopy(node1)
      end
    end
  end
  for (idx2,node2) in agent2.nodes
    if !haskey(agent1.nodes, idx2)
      # Optionally add node2
      if rand() < cr.nodeAddProb
        agent3.nodes[idx2] = deepcopy(node2)
      end
    end
  end

  for edge1 in agent1.edges
    if contains(==, agent2.edges, edge1)
      # Copy all exactly matching edges
      push!(agent3.edges, edge1)
    else
      # If agent3 contains matching nodes, optionally add edge1
      if all(haskey.(agent3.nodes, edge1[1:2]))
        if rand() < cr.edgeAddProb
          push!(agent3.edges, edge1)
        end
      end
    end
  end
  for edge2 in agent2.edges
    if !contains(==, agent1.edges, edge2)
      # If agent3 contains matching nodes, optionally add edge1
      if all(haskey.(agent3.nodes, edge2[1:2]))
        if rand() < cr.edgeAddProb
          push!(agent3.edges, edge2)
        end
      end
    end
  end

  # FIXME: Copy layout, skipping non-existing nodes
  agent3.layout = agent1.layout

  # Clear agent3
  clear!(agent3)
end
