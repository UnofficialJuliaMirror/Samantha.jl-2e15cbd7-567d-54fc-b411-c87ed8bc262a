@testset "Mutation Test" begin
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

  run!(agent)

  profile = MutationProfile()

  push!(profile.mutations, InplaceMutation(GenericNeurons, Dict(
    (:conf, :a) => (1, nothing),
    (:conf, :b) => (0.5, nothing)
  )))
  prev_a = (n1.conf.a, n2.conf.a)
  mutate!(agent, profile)
  next_a = (n1.conf.a, n2.conf.a)
  @test prev_a != next_a
  run!(agent)

  @test_skip "ChangeEdgePatternMutation Tests"
  #=empty!(profile.mutations)
  push!(profile.mutations, ChangeEdgePatternMutation(GenericSynapses, 0.5))
  mutate!(agent, profile)
  run!(agent)=#

  #=push!(profile.mutations, InsertNodeMutation(GenericNeurons, (64,)))
  mutate!(agent, profile)
  @test length(agent.nodes) == 3
  run!(agent)=#
end
