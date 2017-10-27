@testset "Core Tests" begin
  include("core-test.jl")
  include("mutate-test.jl")
  @test_broken "Evolve Test"

  @test_broken "GenericNeurons"
  @test_broken "GenericSynapses"
  @test_broken "ConvNeurons"
  @test_broken "ConvSynapses"
end
