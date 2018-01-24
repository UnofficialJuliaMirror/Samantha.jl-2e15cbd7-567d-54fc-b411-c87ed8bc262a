import Base: delete!

### Types ###

"""
    EvolutionOptimizer

Abstract type for optimizers of evolution simulations.
"""
abstract type EvolutionOptimizer end

"""
    SimpleEnergyOptimizer <: EvolutionOptimizer

Energy-based evolution optimizer.
"""
mutable struct SimpleEnergyOptimizer <: EvolutionOptimizer
  capacity::Int
  initialEnergy::Float64
  energyDecay::Float64
  birthBounds::Tuple{Float64,Float64}
  deathBounds::Tuple{Float64,Float64}
  accidentProb::Float64
  energies::Dict{String,Float64}
  # TODO: lifetimes
end

"""
    AgentProvider

Abstract type for seed agent providers.
"""
abstract type AgentProvider end

"""
    AgentReaper

Abstract type for reapers of dead/expired agents.
"""
abstract type AgentReaper end

"""
    SimpleReaper <: AgentReaper

Simple agent reaper which just deletes the reaped agent.
"""
struct SimpleReaper <: AgentReaper end

"""
    EvolutionProfile

Stores various sub-profiles related to an evolution simulation,
for convenience or for use as default settings.
"""
struct EvolutionProfile
  optimizer::EvolutionOptimizer
  provider::AgentProvider
  reaper::AgentReaper
  mprof::Vector{AbstractMutation}
  rprof::Vector{AbstractRecombination}
  cprof::Vector{Constraint}
  goals::Dict{String,Function}
end
EvolutionProfile(;
  optimizer = SimpleEnergyOptimizer(),
  provider = BareProvider(),
  reaper = SimpleReaper(),
  mprof = AbstractMutation[],
  rprof = AbstractRecombination[],
  cprof = Constraint[],
  goals = Dict{String,Function}()) =
  EvolutionProfile(
    optimizer,
    provider,
    reaper,
    mprof,
    rprof,
    cprof,
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
  EvolutionState(Dict{String,Agent}(), Dict{String,Dict{String,Float64}}(), Dict{String,Dict{String,Dict}}())

### Methods ###

#= FIXME
EvolutionProfile
  Various getters/setters
EvolutionState
  optimize!
    seed!
    reap!
AgentProvider
  add_seed!
  generate_seed
AgentReaper
  reap!
=#

function add_agent!(estate::EvolutionState, name::String)
  estate.agents[name] = agent
  estate.scores[name] = Dict{String,Float64}()
  estate.states[name] = Dict{String,Dict}()
end
function del_agent!(estate::EvolutionState, name::String)
  delete!(estate.agents, name)
  delete!(estate.scores, name)
  delete!(estate.states, name)
end
function step!(estate::EvolutionState)
  for agent in values(estate.agents)
    run!(agent)
  end
end
score!(estate::EvolutionState, eprof::EvolutionProfile) =
  score!(
    estate.agents,
    estate.states,
    estate.scores,
    eprof.goals)
function score!(agents, states, scores, goals)
  for (name,agent) in agents
    for (key,goal) in goals
      scores[name][key] = goal(agent, states[key])
    end
  end
end
optimize!(estate::EvolutionState, eprof::EvolutionProfile) =
  optimize!(
    eprof.optimizer,
    eprof.provider,
    eprof.reaper)
function optimize!(optimizer, provider, reaper)
  # FIXME: Call seed! and reap! as necessary
end
function run!(estate::EvolutionState, eprof::EvolutionProfile)
  step!(estate)
  score!(estate, eprof)
  optimize!(estate, eprof)
end

### SimpleEnergyOptimizer Defaults ###

#add_seed!(opt::SimpleEnergyOptimizer, agent::Agent, name::String) =
#  setindex!(opt.energies, opt.initialEnergy, name)
#Base.delete!(opt::SimpleEnergyOptimizer, name::String) = Base.delete!(opt.energies, name)
#=function compute_bounds(estate::EvolutionState{SimpleEnergyOptimizer})
  # Calculate current birth and death energies
  carryFactor = exp(length(estate.agents) / estate.opt.capacity)-1
  birthLower, birthUpper = estate.opt.birthBounds
  birthEnergy = carryFactor*(birthUpper-birthLower)+birthLower
  deathLower, deathUpper = estate.opt.deathBounds
  deathEnergy = carryFactor*(deathUpper-deathLower)+deathLower
  return (carryFactor, birthEnergy, deathEnergy)
end
function lifecycle_phase!(;
  agents::Dict{String,Agent},
  factors::Dict{String,Function},
  states::Dict{String,Dict{String,Any}},
  scores::Dict{String,Dict{String,Real}},
  mprof::MutationProfile,
  rprof::RecombinationProfile,
  cprof::ConstraintProfile)

  # TODO: Use these to return added/deleted agent ids
  added, deleted = String[], String[]
  
  carryFactor, birthEnergy, deathEnergy = compute_bounds(estate)

  # Update energies based on scores
  for (name,scores) in estate.scores
    estate.opt.energies[name] += sum(values(scores))
  end

  # Mark agents for creation or deletion
  created = Set{String}()
  destroyed = Set{String}()
  for (name,energy) in estate.opt.energies
    if energy > birthEnergy
      push!(created, name)
      estate.opt.energies[name] -= estate.opt.initialEnergy
    end
    if energy < deathEnergy || rand() < estate.opt.accidentProb
      push!(destroyed, name)
    end
    estate.opt.energies[name] *= (1 - estate.opt.energyDecay)
  end
  for name in created
    child = mutate!(deepcopy(estate.agents[name]), estate.profile.mprofile)
    clear!(child)
    child_name = randstring()
    estate[child_name] = child
  end
  for name in destroyed
    delete!(estate, name)
  end

  # Optionally create child as offspring of two agents, including seeds
  # TODO: Improve this significantly (make tunable, adjust based on carryFactor, etc.)
  if rand() < 0.1
    pool = vcat(collect(values(estate.agents)), collect(values(estate.seeds)))
    parent1, parent2 = rand(pool), rand(pool)
    child = recombine(estate.profile.rprofile, parent1, parent2)
    mutate!(child, estate.profile.mprofile)
    estate[randstring()] = child
  end

  # Clone from seeds if necessary
  if length(estate.agents) == 0
    name = randstring()
    agent = mutate!(deepcopy(rand(collect(values(estate.seeds)))), estate.profile.mprofile)
    estate[name] = agent
  end
end=#
