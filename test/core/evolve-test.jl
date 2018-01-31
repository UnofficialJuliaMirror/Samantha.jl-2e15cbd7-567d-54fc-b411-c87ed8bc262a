@testset "Evolution Test" begin
  agent = Agent()

  n1 = GenericNeurons(10)
  n1l = addnode!(agent, n1; name="N1")

  n2 = GenericNeurons(5)
  n2l = addnode!(agent, n2; name="N2")

  s = GenericSynapses(10, 5)
  addnode!(agent, s; name="S")
  addedge!(agent, agent["S"], (
    (n1l, :input),
    (n2l, :output)
  ))

  mprofile = MutationProfile()
  push!(mprofile, InplaceMutation(GenericNeurons, Dict(
    (:conf, :a) => (0.1, nothing),
    (:conf, :b) => (0.1, nothing)
  )))
  
  rprofile = RecombinationProfile()
  push!(rprofile, CheapRecombination(0.1, 0.1))

  eprofile = EvolutionProfile(mutations=mprofile, recombinations=rprofile, optimizer=EnergyOptimizer(16, 100, 0.01, (150, 200), (0, 10), 0.0001))
  estate = EvolutionState()
  add_seed!(eprofile, agent)

  for i = 1:10
    run!(estate, eprofile)
  end
  @test length(estate.agents) >= 1
  @test all(name->haskey(eprofile.optimizer.energies, name), keys(estate.agents))

  add_goal!(eprofile, "test1") do agent, state
    state["temp"] = true
    1
  end
  run!(estate, eprofile)
  @test all(state->haskey(state["test1"], "temp"), values(estate.states))
  @test all(score->score["test1"]==true, values(estate.scores))

  # TODO: Test birth/death bounding creates/destroys agents
end
