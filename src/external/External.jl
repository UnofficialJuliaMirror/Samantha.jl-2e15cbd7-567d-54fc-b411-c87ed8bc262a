using Requires

# TODO: GPUArrays
# TODO: MPI

@require Distributions begin
  function mutate!(num::N, gen::D) where {N<:AbstractFloat, D<:Distributions.Distribution}
    convert(N, rand(gen))
  end
  function mutate!(num::N, gen::D) where {N<:Integer, D<:Distributions.Distribution}
    convert(N, round(rand(gen)))
  end
  function mutate!(arr::A, gen::D) where {A<:AbstractArray{<:AbstractFloat}, D<:Distributions.Distribution}
    convert(A, rand(gen, size(arr)...))
  end
  function mutate!(arr::A, gen::D) where {A<:AbstractArray{<:Integer}, D<:Distributions.Distribution}
    convert(A, round.(rand(gen, size(arr)...)))
  end
end
