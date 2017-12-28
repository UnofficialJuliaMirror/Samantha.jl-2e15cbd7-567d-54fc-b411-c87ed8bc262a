@testset "Recombination Test" begin
  agent1 = Agent()

  n1 = GenericNeurons(10)
  n1l = addnode!(agent1, n1; name="N1")

  n2 = GenericNeurons(5)
  n2l = addnode!(agent1, n2; name="N2")

  s = GenericSynapses(10, 5)
  addnode!(agent1, s; name="S")
  addedge!(agent1, agent1["S"], (
    (n1l, :input),
    (n2l, :output)
  ))

  agent2 = deepcopy(agent1)

  profile = RecombinationProfile()
  push!(profile.recombinations, CheapRecombination(0.1, 0.1))

  agent3 = recombine(profile, agent1, agent2)
  run!(agent3)
end
