using Base: ImmutableDict
using PlasticityBase

function materialproperties(::Type{<:AbstractPlasticity},   material::String)::Dict{String, Float64} end
function materialconstants(::Type{<:AbstractPlasticity},    material::String)::Vector{NamedTuple{key, value}} end
function materialdora(::Type{<:AbstractPlasticity},         material::String)::Vector{NamedTuple{key, value}} end

Base.collect(collection::Vector{<:Pair}) = ImmutableDict(reverse(collection)...)
Base.collect(collection::Vararg{<:Pair}) = collect([collection...])

characteristicequations(::Type{<:AbstractPlasticity})   ::Vector{EquationLabel} = [' ']
dependenceequations(::Type{<:AbstractPlasticity})       ::Vector{EquationLabel} = [' ']
dependencesliders(::Type{<:AbstractPlasticity})         ::Vector{Any}           = Any[]
doraequations(::Type{<:AbstractPlasticity})             ::Vector{EquationLabel} = [' ']
dorasliders(::Type{<:AbstractPlasticity})               ::Vector{Any}           = Any[]

function modeldata(                     ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function modeldora(                     ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function plotdata_initialize(           ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function plotdora_initialize(           ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function plotdata_insert!(              ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function plotdora_insert!(              ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function plotdata_straincontrolkernel(  ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function plotdata_updatekernel(         ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function plotdata_update!(              ::Type{<:AbstractPlasticity}, args...; kwargs...) end
function plotdora_update!(              ::Type{<:AbstractPlasticity}, args...; kwargs...) end