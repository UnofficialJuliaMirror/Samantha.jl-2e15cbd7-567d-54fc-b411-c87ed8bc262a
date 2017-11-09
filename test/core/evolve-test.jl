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
  push!(mprofile.mutations, InplaceMutation(GenericNeurons, Dict(
    (:conf, :a) => (0.1, nothing),
    (:conf, :b) => (0.1, nothing)
  )))

  eprofile = EvolutionProfile(mprofile)
  emode = GenericMode(16, 100, 0.01, (150, 200), (0, 10), 0.0001)
  evstate = EvolutionState(eprofile, emode)
  seed!(evstate, agent)
  @test length(evstate.seeds) == 1

  for i = 1:10
    run!(evstate)
  end
  @test length(evstate.agents) >= 1
  @test all(name->haskey(emode.energies, name), keys(evstate.agents))

  # TODO: Test basic EvalFactor functionality

  # TODO: Test birth/death bounding creates/destroys agents
end
