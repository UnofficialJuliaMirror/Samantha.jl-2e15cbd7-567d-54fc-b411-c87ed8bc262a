### Exports ###

export SymmetricRuleLearn, PowerLawLearn, ExpWeightDepLearn, ConvSynapses

### Types ###

# TODO: Use Value type to select additional modes?
@compgen mutable struct ConvSynapses{L} <: AbstractSynapses
  inputSize::Tuple{Int,Int,Int}
  filterSize::Int
  numFilters::Int
  stride::Int

  learn::L
  
  W::Array{Float32,4}
end
function ConvSynapses(inputSize::Tuple{Int,Int,Int}, filterSize::Int, numFilters::Int, stride::Int=1; learn=SymmetricRuleLearn())
  return ConvSynapses(
    inputSize,
    filterSize,
    numFilters,
    stride,
    learn,
    rand(Float32, inputSize[1], filterSize, filterSize, numFilters) .* 0.3f0
  )
end

### Methods ###

function Base.size(cs::ConvSynapses)
  # FIXME: Stride
  outputSize = (inputSize[2]-filterSize+1, inputSize[3]-filterSize+1, numFilters)
end

function update!(f, cs, stride, W, I, G, F, O)
  @inbounds for fj = indices(W, 3)
    @inbounds for fi = indices(W, 2)
      @inbounds for fc = indices(W, 1)
        @inbounds for oj = indices(O, 2)
          @inbounds for oi = indices(O, 1)
            I_ = Float32(I[fc, oi+fi-1, oj+fj-1]) #Float32(I[fc, (stride*(oi-1))+fi, (stride*(oj-1))+fj])

            # Convolve weights with inputs
            O[oi,oj,f] = muladd(W[fc,fi,fj,f], I_, O[oi,oj,f])
          end
        end
      end
    end
  end
end
function learn!(f, cs, stride, W, I, G, F, O)
  lrn = cs.learn
  const α_pre, α_post, xtar, Wmax, μ = lrn.α_pre, lrn.α_post, lrn.xtar, lrn.Wmax, lrn.μ
  @inbounds for oj = indices(O, 2)
    @inbounds for oi = indices(O, 1)
      @inbounds for fj = indices(W, 3)
        @inbounds for fi = indices(W, 2)
          @inbounds @simd for fc = indices(W, 1)
            I_ = Float32(I[fc, oi+fi-1, oj+fj-1]) #Float32(I[fc, (stride*(oi-1))+fi, (stride*(oj-1))+fj])

            # Learn
            # TODO: Convert I to bool? Or maybe 0-1 (which it will be if coming from CairoNode)
            #W[fc,fi,fj,f] += learn!(cs.learn, I_, G[oi,oj,f], F[oi,oj,f], W[fc,fi,fj,f])
            W[fc,fi,fj,f] += (α_post * F[oi,oj,f] * (I_ - xtar) * (Wmax - W[fc,fi,fj,f]#=^μ=#)) - (α_pre * I_ * G[oi,oj,f] * W[fc,fi,fj,f]#=^μ=#)
          end
        end
      end
    end
  end
end
# TODO: Specify input and output types
function _eforward!(scont::CPUContainer{S}, input, output) where S<:ConvSynapses
  cs = getroot(scont)
  stride, W = cs.stride, cs.W

  I = get(input).data     #@param input[O]
  G = get(output).state.T #@param output[T]
  F = get(output).state.F #@param output[F]
  O = get(output).state.I #@param output[I]
  
  # Clear outputs
  fill!(O, 0f0)

  # Convolve
  @inbounds for f = indices(W, 4)
    update!(f, cs, stride, W, I, G, F, O)
    learn!(f, cs, stride, W, I, G, F, O)
  end

  # Clamp weights
  # TODO: Dispatch on type (or just pull into learn!)
  clamp!(cs.W, 0f0, cs.learn.Wmax)
end
