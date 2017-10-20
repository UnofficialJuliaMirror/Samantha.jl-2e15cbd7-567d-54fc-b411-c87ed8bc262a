@testset "Core Test" begin
  agent = Agent()
  n1 = GenericNeurons(8)
  addnode!(agent, n1; name="N1")
  n2 = GenericNeurons(8)
  addnode!(agent, n2; name="N2")
  s1 = GenericSynapses(8, 8)
  addnode!(agent, s1; name="S1")
  addedge!(agent, agent["S1"], (
    (agent["N1"], :input),
    (agent["N2"], :output)
  ))
  run!(agent)

  @test_broken "delnode!, deledge!"

  # Hooks
  addhook!(agent, "Input", agent["N1"], (:state, :I))
  addhook!(agent, "Output", agent["N2"], (:state, :F))
  delhook!(agent, "Input")
  O = gethook(agent, "Output")
  sethook!(agent, "Output", O)

  # Store/Load
  path = joinpath(SAMANTHA_DATA_PATH, "core-test.h5")
  storefile!(path, agent)
  agent = loadfile(path)
  run!(agent)

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

  # TODO: Clone
end
