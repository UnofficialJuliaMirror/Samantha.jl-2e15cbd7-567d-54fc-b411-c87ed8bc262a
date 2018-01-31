### Types ###

"""
    EvolutionOptimizer

Abstract type for optimizers of evolution simulations.
"""
abstract type EvolutionOptimizer end

"""
    EnergyOptimizer <: EvolutionOptimizer

Energy-based evolution optimizer.
"""
mutable struct EnergyOptimizer <: EvolutionOptimizer
  capacity::Int
  initialEnergy::Float64
  energyDecay::Float64
  birthBounds::Tuple{Float64,Float64}
  deathBounds::Tuple{Float64,Float64}
  accidentProb::Float64
  energies::Dict{String,Float64}
  # TODO: lifetimes
end
EnergyOptimizer(capacity, initialEnergy, energyDecay, birthBounds, deathBounds, accidentProb) =
  EnergyOptimizer(
    capacity,
    initialEnergy,
    energyDecay,
    birthBounds,
    deathBounds,
    accidentProb,
    Dict{String,Float64}())

"""
    LifecycleManager

Abstract type for managers of agent lifecycles.
"""
abstract type LifecycleManager end

"""
    ProgrammableLifecycle <: LifecycleManager

Simple lifecycle manager which exposes seeding and reaping via function hooks.
"""
struct ProgrammableLifecycle <: LifecycleManager
  agent_pool::Dict{String, Agent}
  seed_func::Function
  reap_func::Function
end
ProgrammableLifecycle(seed_func=(agent_pool)->rand(collect(values(agent_pool))), reap_func=agent->nothing) =
  ProgrammableLifecycle(Dict{String, Agent}(), seed_func, reap_func)

"""
    EvolutionProfile

Stores various sub-profiles related to an evolution simulation,
for convenience or for use as default settings.
"""
struct EvolutionProfile
  optimizer::EvolutionOptimizer
  lifecycle::LifecycleManager
  mutations::Vector{AbstractMutation}
  recombinations::Vector{AbstractRecombination}
  constraints::Vector{Constraint}
  goals::Dict{String,Function}
end
EvolutionProfile(;
  optimizer = EnergyOptimizer(),
  lifecycle = ProgrammableLifecycle(),
  mutations = AbstractMutation[],
  recombinations = AbstractRecombination[],
  constraints = Constraint[],
  goals = Dict{String,Function}()) =
  EvolutionProfile(
    optimizer,
    lifecycle,
    mutations,
    recombinations,
    constraints,
    goals)

"""
    EvolutionState{Opt<:EvolutionOptimizer}

Contains the basic state for an evolution simulation.
"""
mutable struct EvolutionState
  agents::Dict{String,Agent}
  scores::Dict{String,Dict{String,Float64}}
  states::Dict{String,Dict{String,Dict}}
end
EvolutionState() =
  EvolutionState(
    Dict{String,Agent}(),
    Dict{String,Dict{String,Float64}}(),
    Dict{String,Dict{String,Dict}}())

### Methods ###

#= FIXME
EvolutionProfile
  Various getters/setters
  optimize!
    seed!
    reap!
LifecycleManager
  add_seed!
  generate_seed
  reap_agent!
Documentation!
=#

add_goal!(func::Function, profile::EvolutionProfile, name::String) =
  setindex!(profile.goals, func, name)
del_goal!(profile::EvolutionProfile, name::String) =
  delete!(profile.goals, name)
add_seed!(profile::EvolutionProfile, agent::Agent, name::String=randstring()) =
  add_seed!(profile.lifecycle, agent, name)
del_seed!(profile::EvolutionProfile, name::String) =
  del_seed!(profile.lifecycle, name)
function add_agent!(estate::EvolutionState, agent::Agent, name::String)
  estate.agents[name] = agent
  estate.scores[name] = Dict{String,Float64}()
  estate.states[name] = Dict{String,Dict}()
end
function del_agent!(estate::EvolutionState, name::String)
  delete!(estate.agents, name)
  delete!(estate.scores, name)
  delete!(estate.states, name)
end
Base.length(estate) = length(estate.agents)
function step!(estate::EvolutionState)
  for agent in values(estate.agents)
    run!(agent)
  end
end
score!(estate::EvolutionState, eprof::EvolutionProfile) = score!(estate, eprof.goals)
function score!(estate, goals)
  for (name,agent) in estate.agents
    for (key,goal) in goals
      estate.scores[name][key] = goal(agent, get!(estate.states[name], key, Dict{String,Any}()))
    end
  end
end
optimize!(estate::EvolutionState, eprof::EvolutionProfile) =
  optimize!(
    estate,
    eprof.optimizer,
    eprof.lifecycle)
function run!(estate::EvolutionState, eprof::EvolutionProfile)
  step!(estate)
  score!(estate, eprof)
  optimize!(estate, eprof)
end

### EnergyOptimizer Methods ###

function _compute_bounds(estate::EvolutionState, optimizer::EnergyOptimizer)
  # Calculate current birth and death energies
  carryFactor = exp(length(estate.agents) / optimizer.capacity)-1
  birthLower, birthUpper = optimizer.birthBounds
  birthEnergy = carryFactor*(birthUpper-birthLower)+birthLower
  deathLower, deathUpper = optimizer.deathBounds
  deathEnergy = carryFactor*(deathUpper-deathLower)+deathLower
  return (carryFactor, birthEnergy, deathEnergy)
end
function optimize!(estate, optimizer::EnergyOptimizer, lifecycle;
  mutations = MutationProfile(),
  recombinations = RecombinationProfile(),
  constraints = ConstraintProfile())
  
  carryFactor, birthEnergy, deathEnergy = _compute_bounds(estate, optimizer)

  # Update energies based on scores
  for (name,scores) in estate.scores
    optimizer.energies[name] += sum(values(scores))
  end

  # Mark agents for creation or deletion
  created = Set{String}()
  destroyed = Set{String}()
  for (name,energy) in optimizer.energies
    if energy > birthEnergy
      push!(created, name)
      optimizer.energies[name] -= optimizer.initialEnergy
    end
    if energy < deathEnergy || rand() < optimizer.accidentProb
      push!(destroyed, name)
    end
    optimizer.energies[name] *= (1 - optimizer.energyDecay)
  end

  # Create or destroy marked agents
  for name in created
    child = mutate!(mutations, deepcopy(estate.agents[name]))
    clear!(child)
    child_name = randstring()
    add_agent!(estate, child, child_name)
    optimizer.energies[child_name] = optimizer.initialEnergy
  end
  for name in destroyed
    del_agent!(estate, name)
    delete!(optimizer.energies, name)
  end

  # Optionally create child as offspring of two agents, including seeds
  # TODO: Improve this significantly (make tunable, adjust based on carryFactor, etc.)
  #=if rand() < 0.1
    parent1 = rand() < 0.5 ? rand(collect(values(estate.agents))) : generate_seed(lifecycle)
    parent2 = rand() < 0.5 ? rand(collect(values(estate.agents))) : generate_seed(lifecycle)
    child = recombine(recombination, parent1, parent2)
    mutate!(mutations, child)
    child_name = randstring()
    add_agent!(estate, child, child_name)
    optimizer.energies[child_name] = optimizer.initialEnergy
  end=#

  # Clone from seeds if necessary
  if length(estate) == 0
    name = randstring()
    agent = mutate!(mutations, generate_seed(lifecycle))
    add_agent!(estate, agent, name)
    optimizer.energies[name] = optimizer.initialEnergy
  end
end

### ProgrammableLifecycle Methods ###

add_seed!(lifecycle::ProgrammableLifecycle, agent::Agent, name::String) =
  setindex!(lifecycle.agent_pool, agent, name)
del_seed!(lifecycle::ProgrammableLifecycle, name::String) =
  delete!(lifecycle.agent_pool, name)
generate_seed(lifecycle::ProgrammableLifecycle) =
  lifecycle.seed_func(lifecycle.agent_pool)
reap_agent!(lifecycle::ProgrammableLifecycle, agent::Agent) =
  lifecycle.reap_func(agent)
