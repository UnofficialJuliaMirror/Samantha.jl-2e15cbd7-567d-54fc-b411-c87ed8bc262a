@testset "Core Test" begin
  agent = Agent()
  n1 = GenericNeurons(8)
  addnode!(agent, n1; name="N1")
  @test length(agent.nodes) == 1
  n2 = GenericNeurons(8)
  addnode!(agent, n2; name="N2")
  s1 = GenericSynapses(8, 8)
  addnode!(agent, s1; name="S1")
  addedge!(agent, agent["S1"], (
    (agent["N1"], :input),
    (agent["N2"], :output)
  ))
  @test length(agent.edges) == 2
  run!(agent)

  nt = GenericNeurons(8)
  addnode!(agent, nt; name="NT")
  st = GenericSynapses(8, 8)
  addnode!(agent, st; name="ST")
  addedge!(agent, agent["ST"], (
    (agent["N1"], :input),
    (agent["NT"], :output)
  ))
  deledge!(agent, agent["ST"], agent["N1"], :input)
  @test length(agent.edges) == 3
  deledge!(agent, agent["ST"], agent["NT"], :output)
  delnode!(agent, agent["ST"])
  @test length(agent.nodes) == 4
  delnode!(agent, agent["NT"])

  # Merge
  agent2 = Agent()
  n3 = GenericNeurons(16)
  addnode!(agent2, n3; name="N3")
  merge!(agent, agent2)
  s2 = GenericSynapses(8, 16)
  addnode!(agent, s2; name="S2")
  addedge!(agent, agent["S2"], (
    (agent["N1"], :input),
    (agent["N3"], :output)
  ))
  run!(agent)
  
  # Clear
  clear!(agent)

  # Deepcopy
  agent2 = deepcopy(agent)
  run!(agent2)

  # Size
  for (idx, node) in agent.nodes
    @test size(root(node)) != nothing
  end
end
