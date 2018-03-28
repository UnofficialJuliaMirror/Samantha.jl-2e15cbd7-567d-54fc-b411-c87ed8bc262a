@testset "Core Test" begin
  agent = Agent()
  n1 = addnode!(agent, GenericNeurons(8))
  @test length(agent.nodes) == 1
  n2 = addnode!(agent, GenericNeurons(8))
  s1 = addnode!(agent, GenericSynapses(8, 8))
  addedge!(agent, s1, (
    (n1, :input),
    (n2, :output)
  ))
  @test length(agent.edges) == 2
  run!(agent)

  nt = addnode!(agent, GenericNeurons(8))
  st = addnode!(agent, GenericSynapses(8, 8))
  addedge!(agent, st, (
    (n1, :input),
    (nt, :output)
  ))
  deledge!(agent, st, n1, :input)
  @test length(agent.edges) == 3
  deledge!(agent, st, nt, :output)
  delnode!(agent, st)
  @test length(agent.nodes) == 4
  delnode!(agent, nt)

  # Merge
  agent2 = Agent()
  n3 = addnode!(agent2, GenericNeurons(16))
  merge!(agent, agent2)
  s2 = addnode!(agent, GenericSynapses(8, 16))
  addedge!(agent, s2, (
    (n1, :input),
    (n3, :output)
  ))
  run!(agent)
  
  # Clear
  Samantha.clear!(agent)

  # Deepcopy
  agent2 = deepcopy(agent)
  run!(agent2)

  # Size
  for (idx, node) in agent.nodes
    @test size(root(node)) != nothing
  end
end
