# This file is a part of Julia. License is MIT: https://julialang.org/license

## floating-point functions ##

copysign(x::Float64, y::Float64) = copysign_float(x, y)
copysign(x::Float32, y::Float32) = copysign_float(x, y)
copysign(x::Float32, y::Real) = copysign(x, Float32(y))
copysign(x::Float64, y::Real) = copysign(x, Float64(y))

flipsign(x::Float64, y::Float64) = bitcast(Float64, xor_int(bitcast(UInt64, x), and_int(bitcast(UInt64, y), 0x8000000000000000)))
flipsign(x::Float32, y::Float32) = bitcast(Float32, xor_int(bitcast(UInt32, x), and_int(bitcast(UInt32, y), 0x80000000)))
flipsign(x::Float32, y::Real) = flipsign(x, Float32(y))
flipsign(x::Float64, y::Real) = flipsign(x, Float64(y))

signbit(x::Float64) = signbit(bitcast(Int64, x))
signbit(x::Float32) = signbit(bitcast(Int32, x))
signbit(x::Float16) = signbit(bitcast(Int16, x))

"""
    maxintfloat(T=Float64)

The largest consecutive integer that is exactly represented in the given floating-point type `T`
(which defaults to `Float64`).

That is, `maxintfloat` returns the smallest positive integer `n` such that `n+1`
is *not* exactly representable in the type `T`.
"""
maxintfloat(::Type{Float64}) = 9007199254740992.
maxintfloat(::Type{Float32}) = Float32(16777216.)
maxintfloat(::Type{Float16}) = Float16(2048f0)
maxintfloat(x::T) where {T<:AbstractFloat} = maxintfloat(T)

"""
    maxintfloat(T, S)

The largest consecutive integer representable in the given floating-point type `T` that
also does not exceed the maximum integer representable by the integer type `S`.  Equivalently,
it is the minimum of `maxintfloat(T)` and [`typemax(S)`](@ref).
"""
maxintfloat(::Type{S}, ::Type{T}) where {S<:AbstractFloat, T<:Integer} = min(maxintfloat(S), S(typemax(T)))
maxintfloat() = maxintfloat(Float64)

isinteger(x::AbstractFloat) = (x - trunc(x) == 0)

"""
    round([T,] x, [r::RoundingMode])
    round(x, [r::RoundingMode]; digits::Integer= [, base = 10])
    round(x, [r::RoundingMode]; sigdigits::Integer= [, base = 10])

Rounds the number `x`.

Without keyword arguments, `x` is rounded to an integer value, returning a value of type
`T`, or of the same type of `x` if no `T` is provided. An [`InexactError`](@ref) will be
thrown if the value is not representable by `T`, similar to [`convert`](@ref).

If the `digits` keyword argument is provied, it rounds to the specified number of digits
after the decimal place (or before if negative), in base `base`.

If the `sigdigits` keyword argument is provided, it rounds to the specified number of
significant digits, in base `base`.

The [`RoundingMode`](@ref) `r` controls the direction of the rounding; the default is
[`RoundNearest`](@ref), which rounds to the nearest integer, with ties (fractional values
of 0.5) being rounded to the nearest even integer. Note that `round` may give incorrect
results if the global rounding mode is changed (see [`rounding`](@ref)).

# Examples
```jldoctest
julia> round(1.7)
2.0

julia> round(Int, 1.7)
2

julia> round(1.5)
2.0

julia> round(2.5)
2.0

julia> round(pi; digits=2)
3.14

julia> round(pi; digits=3, base=2)
3.125

julia> round(123.456; sigdigits=2)
120.0

julia> round(357.913; sigdigits=4, base=2)
352.0
```

!!! note
    Rounding to specified digits in bases other than 2 can be inexact when
    operating on binary floating point numbers. For example, the [`Float64`](@ref)
    value represented by `1.15` is actually *less* than 1.15, yet will be
    rounded to 1.2.

    # Examples
    ```jldoctest; setup = :(using Printf)
    julia> x = 1.15
    1.15

    julia> @sprintf "%.20f" x
    "1.14999999999999991118"

    julia> x < 115//100
    true

    julia> round(x, 1)
    1.2
    ```

# Extensions

To extend `round` to new numeric types, it is typically sufficient to define `Base._round(x::NewType, ::RoundingMode)`.
"""
round(T::Type, x)

round(::Type{T}, x::AbstractFloat, r::RoundingMode{:ToZero}) where {T<:Integer} = trunc(T, x)
round(::Type{T}, x::AbstractFloat, r::RoundingMode) where {T<:Integer} = trunc(T, _round(x,r))

function round(x, r::RoundingMode=RoundNearest;
    digits::Union{Nothing,Integer}=nothing, sigdigits::Union{Nothing,Integer}=nothing, base=10)
    _round(x,r,digits,sigdigits,base)
end
trunc(x; kwargs...) = round(x, RoundToZero; kwargs...)
floor(x; kwargs...) = round(x, RoundDown; kwargs...)
ceil(x; kwargs...)  = round(x, RoundUp; kwargs...)

_round(x, r::RoundingMode, digits::Nothing, sigdigits::Nothing, base) = _round(x, r)
_round(x::Integer, r::RoundingMode) = x

function _round(x, r::RoundingMode, digits::Integer, sigdigits::Nothing, base)
    if digits >= 0
        sc = oftype(fx, base)^digits
        r = round(fx * sc, r) / sc
    else
        isc = oftype(fx, base)^-digits
        r = round(fx / isc, r) * isc
    end
    
    if !isfinite(r)
        if digits > 0
            return fx
        elseif x > 0
            return (r == RoundUp ? oftype(x, Inf) : zero(fx))
        elseif x < 0
            return (r == RoundDown ? -oftype(x, Inf) : -zero(fx))
        else
            return fx
        end
    end
    return r
end

hidigit(x::Integer, base) = ndigits0z(x, base)
function hidigit(x::Real, base)
    fx = float(x)
    if base == 10
        return 1 + floor(Int, log10(abs(fx)))
    elseif base == 2
        return 1 + exponent(x)
    else
        return 1 + floor(Int, log(abs(fx), base))
    end
end

function _round(x, r::RoundingMode, digits::Nothing, sigdigits::Integer, base)
    h = hidigit(x, base)
    _round(x, r, sigdigits-h, nothing, base)
end

_round(x, r::RoundingMode, digits::Integer, sigdigits::Integer, base) =
    throw(ArgumentError("`round` cannot use both `digits` and `sigdigits` arguments.")

# C-style round
function _round(x::AbstractFloat, ::RoundingMode{:NearestTiesAway})
    y = trunc(x)
    ifelse(x==y,y,trunc(2*x-y))
end
# Java-style round
function _round(x::AbstractFloat, ::RoundingMode{:NearestTiesUp})
    y = floor(x)
    ifelse(x==y,y,copysign(floor(2*x-y),x))
end

# isapprox: approximate equality of numbers
"""
    isapprox(x, y; rtol::Real=atol>0 ? 0 : √eps, atol::Real=0, nans::Bool=false, norm::Function)

Inexact equality comparison: `true` if `norm(x-y) <= max(atol, rtol*max(norm(x), norm(y)))`. The
default `atol` is zero and the default `rtol` depends on the types of `x` and `y`. The keyword
argument `nans` determines whether or not NaN values are considered equal (defaults to false).

For real or complex floating-point values, if an `atol > 0` is not specified, `rtol` defaults to
the square root of [`eps`](@ref) of the type of `x` or `y`, whichever is bigger (least precise).
This corresponds to requiring equality of about half of the significand digits. Otherwise,
e.g. for integer arguments or if an `atol > 0` is supplied, `rtol` defaults to zero.

`x` and `y` may also be arrays of numbers, in which case `norm` defaults to `vecnorm` but
may be changed by passing a `norm::Function` keyword argument. (For numbers, `norm` is the
same thing as `abs`.) When `x` and `y` are arrays, if `norm(x-y)` is not finite (i.e. `±Inf`
or `NaN`), the comparison falls back to checking whether all elements of `x` and `y` are
approximately equal component-wise.

The binary operator `≈` is equivalent to `isapprox` with the default arguments, and `x ≉ y`
is equivalent to `!isapprox(x,y)`.

Note that `x ≈ 0` (i.e., comparing to zero with the default tolerances) is
equivalent to `x == 0` since the default `atol` is `0`.  In such cases, you should either
supply an appropriate `atol` (or use `norm(x) ≤ atol`) or rearrange your code (e.g.
use `x ≈ y` rather than `x - y ≈ 0`).   It is not possible to pick a nonzero `atol`
automatically because it depends on the overall scaling (the "units") of your problem:
for example, in `x - y ≈ 0`, `atol=1e-9` is an absurdly small tolerance if `x` is the
[radius of the Earth](https://en.wikipedia.org/wiki/Earth_radius) in meters,
but an absurdly large tolerance if `x` is the
[radius of a Hydrogen atom](https://en.wikipedia.org/wiki/Bohr_radius) in meters.


# Examples
```jldoctest
julia> 0.1 ≈ (0.1 - 1e-10)
true

julia> isapprox(10, 11; atol = 2)
true

julia> isapprox([10.0^9, 1.0], [10.0^9, 2.0])
true

julia> 1e-10 ≈ 0
false

julia> isapprox(1e-10, 0, atol=1e-8)
true
```
"""
function isapprox(x::Number, y::Number; atol::Real=0, rtol::Real=rtoldefault(x,y,atol), nans::Bool=false)
    x == y || (isfinite(x) && isfinite(y) && abs(x-y) <= max(atol, rtol*max(abs(x), abs(y)))) || (nans && isnan(x) && isnan(y))
end

const ≈ = isapprox
"""
    x ≉ y

This is equivalent to `!isapprox(x,y)` (see [`isapprox`](@ref)).
"""
≉(args...; kws...) = !≈(args...; kws...)

# default tolerance arguments
rtoldefault(::Type{T}) where {T<:AbstractFloat} = sqrt(eps(T))
rtoldefault(::Type{<:Real}) = 0
function rtoldefault(x::Union{T,Type{T}}, y::Union{S,Type{S}}, atol::Real) where {T<:Number,S<:Number}
    rtol = max(rtoldefault(real(T)),rtoldefault(real(S)))
    return atol > 0 ? zero(rtol) : rtol
end

# fused multiply-add

"""
    fma(x, y, z)

Computes `x*y+z` without rounding the intermediate result `x*y`. On some systems this is
significantly more expensive than `x*y+z`. `fma` is used to improve accuracy in certain
algorithms. See [`muladd`](@ref).
"""
function fma end

fma_libm(x::Float32, y::Float32, z::Float32) =
    ccall(("fmaf", libm_name), Float32, (Float32,Float32,Float32), x, y, z)
fma_libm(x::Float64, y::Float64, z::Float64) =
    ccall(("fma", libm_name), Float64, (Float64,Float64,Float64), x, y, z)
fma_llvm(x::Float32, y::Float32, z::Float32) = fma_float(x, y, z)
fma_llvm(x::Float64, y::Float64, z::Float64) = fma_float(x, y, z)
# Disable LLVM's fma if it is incorrect, e.g. because LLVM falls back
# onto a broken system libm; if so, use openlibm's fma instead
# 1.0000305f0 = 1 + 1/2^15
# 1.0000000009313226 = 1 + 1/2^30
# If fma_llvm() clobbers the rounding mode, the result of 0.1 + 0.2 will be 0.3
# instead of the properly-rounded 0.30000000000000004; check after calling fma
if (Sys.ARCH != :i686 && fma_llvm(1.0000305f0, 1.0000305f0, -1.0f0) == 6.103609f-5 &&
    (fma_llvm(1.0000000009313226, 1.0000000009313226, -1.0) ==
     1.8626451500983188e-9) && 0.1 + 0.2 == 0.30000000000000004)
    fma(x::Float32, y::Float32, z::Float32) = fma_llvm(x,y,z)
    fma(x::Float64, y::Float64, z::Float64) = fma_llvm(x,y,z)
else
    fma(x::Float32, y::Float32, z::Float32) = fma_libm(x,y,z)
    fma(x::Float64, y::Float64, z::Float64) = fma_libm(x,y,z)
end
function fma(a::Float16, b::Float16, c::Float16)
    Float16(fma(Float32(a), Float32(b), Float32(c)))
end

# This is necessary at least on 32-bit Intel Linux, since fma_llvm may
# have called glibc, and some broken glibc fma implementations don't
# properly restore the rounding mode
Rounding.setrounding_raw(Float32, Rounding.JL_FE_TONEAREST)
Rounding.setrounding_raw(Float64, Rounding.JL_FE_TONEAREST)
