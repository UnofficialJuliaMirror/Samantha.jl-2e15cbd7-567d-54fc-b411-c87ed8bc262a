### Types ###

@nodegen mutable struct SymmetricRuleLearn
  α_pre::Float32
  α_post::Float32
  xtar::Float32 
  Wmax::Float32 
  μ::Int
end
SymmetricRuleLearn() = SymmetricRuleLearn(0.1, 0.5, 0.5, 5, 1)
@nodegen mutable struct PowerLawLearn
  α::Float32
  xtar::Float32
  Wmax::Float32
  μ::Float32
end
PowerLawLearn() = PowerLawLearn(0.1, 0.5, 5, 1)
@nodegen mutable struct ExpWeightDepLearn
  α::Float32
  xtar::Float32
  Wmax::Float32
  μ::Float32
  β::Float32
end
ExpWeightDepLearn() = ExpWeightDepLearn(0.1, 0.5, 5, 1, 1)

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
