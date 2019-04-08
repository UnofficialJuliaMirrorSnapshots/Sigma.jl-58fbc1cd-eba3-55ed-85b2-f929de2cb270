## Design Decisions
#
# - Second majo design question is who what kind of random variable to pass to
# the solver
# initially we tried to make the preimage smaplers agnostic to what type of
# random variable
# it was passed.  The randvar need only implement call(X, A).  However
# -- If the algorith is parallelised, it may need generate the C typed rand
# Varvar
# -- sol 1. Make these preimage samplers expect the RandVar type and they can
# do their own conversion
# -- sol 2. Have some kind of buffer between the different cases


# Three axes to classify samplers:
# (i) Uncoditional samples vs (ii) conditional samples
# (i) concrete (e.g. Float64) samples, vs (ii) abstract (e.g. Interval) samples)
# (i) return elements of type T, or (ii) elements abstractions of T, e.g.


## Unconditional Sampling
## ======================

"single uncoditional random sample from `X`"
rand{T}(X::JuliaRandVar{T}) = X(LazyRandomVector(Float64))

"e`n` i.i.d. unconditional random samples from X"
rand{T}(X::JuliaRandVar{T}, n::Integer) =
  [X(LazyRandomVector(Float64)) for i = 1:n]


rand{T}(X::SymbolicRandVar{T}, n::Integer) =
  rand(convert(JuliaRandVar{T},X), n)


## RandVar{Bool} Preimage Samples
## ==============================

# Note args named x_sampler sample *from* x, e.g.
# partition_sampler samples set from partition (not a partition itself)

"`n` abstract samples from preimage: Y^-1({true}) using `partition_alg`"
function abstract_sample_partition(
    Y::SymbolicRandVar{Bool},
    n::Integer;
    partition_alg::Type{BFSPartition} = BFSPartition,
    args...)

  partition = pre_partition(Y, partition_alg; args...)
  rand(partition, n)
end

"`n` point samples from preimage: Y^-1({true})"
function point_sample_partition{T<:PartitionAlgorithm}(
    Y::SymbolicRandVar{Bool},
    n::Integer;
    partition_alg::Type{T} = BFSPartition,
    partition_sampler::Function = point_sample,
    args...)
  # FIXME: Float64 too specific
  p = pre_partition(Y, partition_alg; args...)
  s_p = SampleablePartition(p)
  partition_sampler(s_p, n)
end

## Markokv Chain Conditional Sampling
## ==================================
"""`n` approximate point sample from preimage: Y^-1({true})
"""
function point_sample_mc{T<:MCMCAlgorithm}(
    Y::SymbolicRandVar{Bool},
    n::Integer;
    ChainAlg::Type{T} = AMS,    # Generate Markov Chain of samples
    chain_sampler::Function = point_sample, # Sample from Markov Chain
    args...)

  # FIXME: Float64 too specific
  chain = pre_mc(Y, n, ChainAlg; args...)
  chain_sampler(chain)
end

## Samples from X given Y
## ======================

# FIXME, this is not the best way to do it.  This method, finds the preiamge samples
# Then just runs them using interva arithmetic.  In order to do this properly you
# need to pave both ways

"`n` conditional samples from `X` given `Y` is true"
function rand{T}(
    X::SymbolicRandVar{T},
    Y::SymbolicRandVar{Bool},
    n::Integer;
    preimage_sampler::Function = point_sample_mc,
    args...)

  executable_X = convert(JuliaRandVar{T}, X)
  preimage_samples = preimage_sampler(Y, n; args...)
  T[executable_X(sample) for sample in preimage_samples]
end

"Sample from a tuple of values `(X_1, X_2, ..., X_m) conditioned on `Y`"
function rand(
    X::Tuple,
    Y::SymbolicRandVar{Bool},
    n::Integer;
    preimage_sampler::Function = point_sample_mc,
    args...)

  preimage_samples = preimage_sampler(Y, n; args...)

  # There are two natural ways to return the tuples
  # 1. tuple of m (num in tuple) vectors, each n samples long
  # 2. vector of `n` tuples of length `m` <-- we do this oen

  # types = map(x->Vector{rangetype(x)}, X)
  samples = Array[]
  for x in X
    RT = rangetype(x)
    executable_X = executionalize(x)
    xsamples = RT[executable_X(sample) for sample in preimage_samples]
    push!(samples, xsamples)
  end
  samples
  map(tuple, samples...)
  # tuple(samples...)
end

## One Sample
## ==========

"Generate a sample from a rand array `Xs` conditioned on `Y`"
rand(Xs::Ex, Y::SymbolicRandVar{Bool}; args...) =  rand(Xs,Y,1;args...)[1]

"Generate a sample from a randvar `X` conditioned on `Y`"
rand(X::SymbolicRandVar, Y::SymbolicRandVar{Bool}; args...) = rand(X,Y,1; args...)[1]

"Generate an unconditioned random sample from X"
rand{T}(X::SymbolicRandVar{T}) = rand(X,1)[1]

"Generate single conditionam sample of tuple `X` of RandVar/Arrays given `Y`"
rand(X::Tuple, Y::SymbolicRandVar{Bool}; args...) = rand(X,Y,1;args...)[1]
