@testset "Core Tests" begin
  include("core-test.jl")
  @test_broken "Mutate Test"
  @test_broken "Evolve Test"

  @test_broken "GenericNeurons"
  @test_broken "GenericSynapses"
  @test_broken "ConvNeurons"
  @test_broken "ConvSynapses"
end
