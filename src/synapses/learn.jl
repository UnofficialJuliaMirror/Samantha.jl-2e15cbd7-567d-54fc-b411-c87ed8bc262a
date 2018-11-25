### Types ###

@with_kw mutable struct HebbianDecayLearn
  α::Float32 = 0.01f0
  β::Float32 = 0.9f0
  Wmax::Float32 = 1.0f0
end
@with_kw mutable struct SymmetricRuleLearn
  α_pre::Float32 = 0.1f0
  α_post::Float32 = 0.5f0
  xtar::Float32 = 0.5f0
  Wmax::Float32 = 5f0
  μ::Int =1f0
end
@with_kw mutable struct PowerLawLearn
  α::Float32 = 0.1f0
  xtar::Float32 = 0.5f0
  Wmax::Float32 = 5f0
  μ::Float32 = 1f0
end
@with_kw mutable struct ExpWeightDepLearn
  α::Float32 = 0.1f0
  xtar::Float32 = 0.5f0
  Wmax::Float32 = 5f0
  μ::Float32 = 1f0
  β::Float32 = 1f0
end
@with_kw mutable struct BCMLearn
  α::Float32 = 0.1f0
  ϵ::Float32 = 1f0
  θM::Matrix{Float32}
  # FIXME: Histories
end

#= TODO
  ## Old algorithms
  # Update weights with modified Oja's rule:
  # Traces as x and gradients as y (temporal averaging)
  #W[n,i] += learnRate * ((T[n,i] * G[n]) - (G[n] * G[n] * W[n,i])) * G[n] * T[n,i] #* (G[n] - T[n,i])
  #W[n,i] += learnRate * (T[n,i] - ((G[n] * W[n,i]) * G[n])) * T[n,i]
  #W[n,i] += learnRate * (T[n,i] * G[n] * (G[n] - W[n,i]))
  #W[n,i] = clamp(W[n,i], 0.01f0, 1f0)
=#

### Methods ###

@inline function learn!(lrn::HebbianDecayLearn, I, G, F, W)
  α, β, Wmax = lrn.α, lrn.β, lrn.Wmax
  return α * ((F * G * W) - (β * W))
end
@inline function learn!(lrn::SymmetricRuleLearn, I, G, F, W)
  α_pre, α_post, xtar, Wmax, μ = lrn.α_pre, lrn.α_post, lrn.xtar, lrn.Wmax, lrn.μ
  return (α_post * F * (I - xtar) * (Wmax - W^μ)) - (α_pre * I * G * W^μ)
end
# TODO: Inspect both of these:
@inline function learn!(lrn::PowerLawLearn, I, G, F, W)
  α, xtar, Wmax, μ = lrn.α, lrn.xtar, lrn.Wmax, lrn.μ
  return α * F * (G - xtar) * (Wmax - W)^μ
end
@inline function learn!(lrn::ExpWeightDepLearn, I, G, F, W)
  α, xtar, Wmax, μ, β = lrn.α, lrn.xtar, lrn.Wmax, lrn.μ, lrn.β
  return α * F * ((G * exp(-β * W)) - (xtar * exp(-β * (Wmax - W))))
end
@inline function learn!(lrn::BCMLearn, I, G, F, W)
  α, ϵ, θM = lrn.α, lrn.ϵ, lrn.θM
  # FIXME
end
