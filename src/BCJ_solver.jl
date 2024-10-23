abstract type BCJ_base end
abstract type Bammann1990Modeling   <: BCJ_base end
abstract type DK                    <: BCJ_base end

struct BCJ_metal{T1<:Integer, T2<:AbstractFloat}
    θ       ::T2                # applied temperature
    ϵ_dot   ::T2                # applied strain rate
    ϵₙ      ::T2                # final strain
    N       ::T1                # number of strain increments
    istate  ::T1                # load type (1: uniaxial tension; 2: torsion)
    params  ::Dict{String, T2}  # material constants
end

mutable struct BCJ_metal_currentconfiguration{BaseVersion<:BCJ_base, T<:AbstractFloat}
    N               ::Integer   # number of strain increments
    μ               ::T         # shear modulus at temperature, θ
    σ__             ::Matrix{T} # deviatoric stress tensor
    σₜᵣ__           ::Matrix{T} # deviatoric stress tensor (trial)
    ϵₚ__            ::Matrix{T} # plastic strain tensor
    ϵ__             ::Matrix{T} # total strain tensor
    Δϵ              ::Matrix{T} # strain increment
    ξ__             ::Matrix{T} # overstress tensor (S - 2/3*alpha)
    Δt              ::T         # timestep
    ϵ_dot_effective ::T         # strain rate (effective)
    ϵ_dot_plastic__ ::Matrix{T} # plastic strain rate
    V               ::T         # strain rate sensitivity of yield stress at temperature, θ
    Y               ::T         # rate independent yield stress at temperature, θ
    f               ::T         # strain rate at which yield becomes strain rate dependent at temperature, θ
    h               ::T         # kinematic hardening modulus at temperature, θ
    r_d             ::T         # dynamic recovery of kinematic hardening at temperature, θ
    r_s             ::T         # diffusion controlled static/thermal recovery of kinematic hardening at temperature, θ
    H               ::T         # isotropic hardening modulus at temperature, θ
    R_d             ::T         # dynamic recovery of isotropic hardening at temperature, θ
    R_s             ::T         # diffusion controlled static/thermal recovery of isotropic hardening at temperature, θ
    α__             ::Matrix{T} # kinematic hardening tensor
    αₜᵣ__           ::Matrix{T} # kinematic hardening tensor (trial)
    κ               ::Vector{T} # isotropic hardening scalar
    β               ::T         # yield function
end

function BCJ_metal_currentconfiguration_init(BCJ::BCJ_metal, BaseVersion::Type{Bammann1990Modeling})::BCJ_metal_currentconfiguration
    θ       = BCJ.θ
    ϵ_dot   = BCJ.ϵ_dot
    ϵₙ      = BCJ.ϵₙ
    N       = BCJ.N
    istate  = BCJ.istate
    params  = BCJ.params
    M       = N + 1
    T       = typeof(float(θ))
    # breakout params into easy variables
    G       = params["bulk_mod"]
    μ       = params["shear_mod"]
    # params_keys = keys(params)
    # C = params[params_keys[findall(r"C\d+", params_keys)]]
    C1      = params["C01"]
    C2      = params["C02"]
    C3      = params["C03"]
    C4      = params["C04"]
    C5      = params["C05"]
    C6      = params["C06"]
    C7      = params["C07"]
    C8      = params["C08"]
    C9      = params["C09"]
    C10     = params["C10"]
    C11     = params["C11"]
    C12     = params["C12"]
    C13     = params["C13"]
    C14     = params["C14"]
    C15     = params["C15"]
    C16     = params["C16"]
    C17     = params["C17"]
    C18     = params["C18"]
    C19     = params["C19"]
    C20     = params["C20"]


    # array declarations
    # * tenXirs: # = [#_11, #_22, #_33, #_12, #_23, #_13]
    ## OSVs
    σ__             = zeros(T, (6, M))  # deviatoric stress
    ϵₚ__            = zeros(T, (6, M))  # plastic strain
    ϵ__             = zeros(T, (6, M))  # total strain
    ϵ_dot_plastic__ = zeros(T, (6, M))  # plastic strain rate
    ## ISVs
    α__             = zeros(T, (6, M))  # alpha: kinematic hardening
    κ               = zeros(T,     M )  # kappa: isotropic hardening
    ## holding values
    Δϵ              = zeros(T, (6, 1))  # strain increment
    σₜᵣ__           = zeros(T, (6, 1))  # trial stress  (deviatoric)
    αₜᵣ__           = zeros(T, (6, 1))  # trial kinematic
    ξ__             = zeros(T, (6, M))  # overstress (S - 2/3*alpha)

    # initialize variables (non-zeros)
    σ__[:, 1]  .= 0.0
    ϵ__[:, 1]  .= 0.0
    ϵₚ__[:, 1] .= 0.0
    α__[:, 1]  .= 0.0000001
    κ[1]        = 0.0
    ϵ_dot_plastic__[:, 1] .= 0.0


    # state evaluation - loading type
    ϵ_dot_effective = if istate == 1    # uniaxial tension
        δϵ  = ϵₙ / N
        Δϵ .= [δϵ, -0.499δϵ, -0.499δϵ, 0., 0., 0.]
        Δt  = δϵ / ϵ_dot # timestep
        ϵ_dot
    elseif istate == 2                  # torsion
        # convert equivalent strain to true shear strain
        ϵₙ *= 0.5 * √(3.)
        Δϵ .= [0., 0., 0., ϵₙ / N, 0., 0.]
        # equivalent strain rate to true shear strain rate
        Δt  = Δϵ[3] / ϵ_dot            # timestep
        2ϵ_dot / √3.
    end


    # temperature dependent constants
    V   = C1    * exp( -C2 / θ )
    Y   = C3    * exp(  C4 / θ )
    f   = C5    * exp( -C6 / θ )

    β   = Y + (V * asinh( ϵ_dot_effective / f ))

    r_d = C7    * exp( -C8  / θ )
    h   = C9    * exp(  C10 * θ )
    r_s = C11   * exp( -C12 / θ )

    R_d = C13   * exp( -C14 / θ )
    H   = C15   * exp(  C16 * θ )
    R_s = C17   * exp( -C18 / θ )
    return BCJ_metal_currentconfiguration{BaseVersion, T}(
        N, μ, σ__, σₜᵣ__, ϵₚ__, ϵ__, Δϵ, ξ__,
        Δt, ϵ_dot_effective, ϵ_dot_plastic__,
        V, Y, f, h, r_d, r_s, H, R_d, R_s, α__, αₜᵣ__, κ, β)
end

function BCJ_metal_currentconfiguration_init(BCJ::BCJ_metal, BaseVersion::Type{DK})::BCJ_metal_currentconfiguration
    θ       = BCJ.θ
    ϵ_dot   = BCJ.ϵ_dot
    ϵₙ      = BCJ.ϵₙ
    N       = BCJ.N
    istate  = BCJ.istate
    params  = BCJ.params
    M       = N + 1
    T       = typeof(float(θ))
    # breakout params into easy variables
    G       = params["bulk_mod"]
    μ       = params["shear_mod"]
    # params_keys = keys(params)
    # C = params[params_keys[findall(r"C\d+", params_keys)]]
    C1      = params["C01"]
    C2      = params["C02"]
    C3      = params["C03"]
    C4      = params["C04"]
    C5      = params["C05"]
    C6      = params["C06"]
    C7      = params["C07"]
    C8      = params["C08"]
    C9      = params["C09"]
    C10     = params["C10"]
    C11     = params["C11"]
    C12     = params["C12"]
    C13     = params["C13"]
    C14     = params["C14"]
    C15     = params["C15"]
    C16     = params["C16"]
    C17     = params["C17"]
    C18     = params["C18"]
    C19     = params["C19"]
    C20     = params["C20"]


    # array declarations
    # * tenXirs: # = [#_11, #_22, #_33, #_12, #_23, #_13]
    ## OSVs
    σ__             = zeros(T, (6, M))  # deviatoric stress
    ϵₚ__            = zeros(T, (6, M))  # plastic strain
    ϵ__             = zeros(T, (6, M))  # total strain
    ϵ_dot_plastic__ = zeros(T, (6, M))  # plastic strain rate
    ## ISVs
    α__             = zeros(T, (6, M))  # alpha: kinematic hardening
    κ               = zeros(T,     M )  # kappa: isotropic hardening
    ## holding values
    Δϵ              = zeros(T, (6, 1))  # strain increment
    σₜᵣ__           = zeros(T, (6, 1))  # trial stress  (deviatoric)
    αₜᵣ__           = zeros(T, (6, 1))  # trial kinematic
    ξ__             = zeros(T, (6, M))  # overstress (S - 2/3*alpha)

    # initialize variables (non-zeros)
    σ__[:, 1]  .= 0.0
    ϵ__[:, 1]  .= 0.0
    ϵₚ__[:, 1] .= 0.0
    α__[:, 1]  .= 0.0000001
    κ[1]        = 0.0
    ϵ_dot_plastic__[:, 1] .= 0.0


    # state evaluation - loading type
    if istate == 1    # uniaxial tension
        δϵ  = ϵₙ / N
        Δϵ .= [δϵ, -0.499δϵ, -0.499δϵ, 0., 0., 0.]
        Δt  = δϵ / ϵ_dot # timestep
        ϵ_dot_effective = ϵ_dot
    elseif istate == 2                  # torsion
        # convert equivalent strain to true shear strain
        ϵₙ *= 0.5 * √(3.)
        Δϵ .= [0., 0., 0., ϵₙ / N, 0., 0.]
        # equivalent strain rate to true shear strain rate
        Δt  = Δϵ[3] / ϵ_dot            # timestep
        ϵ_dot_effective = 2ϵ_dot / √3.
    end


    # temperature dependent constants
    V   = C1    * exp( -C2 / θ )
    Y   = C3    * exp(  C4 / θ )
    f   = C5    * exp( -C6 / θ )

    β   = Y + (V * asinh( ϵ_dot_effective / f ))

    r_d = C7    * exp( -C8  / θ )
    h   = C9    -    (  C10 * θ )
    r_s = C11   * exp( -C12 / θ )

    R_d = C13   * exp( -C14 / θ )
    H   = C15   -    (  C16 * θ )
    R_s = C17   * exp( -C18 / θ )

    Y  *= (C19 < 0.) ? (1.) : (0.5 * ( 1.0 + tanh(max(0., C19 * ( C20 - θ )))))
    return BCJ_metal_currentconfiguration{BaseVersion, T}(
        N, μ, σ__, σₜᵣ__, ϵₚ__, ϵ__, Δϵ, ξ__,
        Δt, ϵ_dot_effective, ϵ_dot_plastic__,
        V, Y, f, h, r_d, r_s, H, R_d, R_s, α__, αₜᵣ__, κ, β)
end


"""
Function to get a full stress-strain curve (and ISV values)

params = material constants

istate: 1 = tension, 2 = torsion

**no damage in this model**
"""
function solve!(BCJ::BCJ_metal_currentconfiguration{Bammann1990Modeling, <:Real})
    μ               = BCJ.μ
    σ__, σₜᵣ__      = BCJ.σ__, BCJ.σₜᵣ__
    ϵₚ__, ϵ__, Δϵ   = BCJ.ϵₚ__, BCJ.ϵ__, BCJ.Δϵ
    ξ__             = BCJ.ξ__
    Δt              = BCJ.Δt
    ϵ_dot_effective = BCJ.ϵ_dot_effective
    ϵ_dot_plastic__ = BCJ.ϵ_dot_plastic__
    V, Y, f         = BCJ.V, BCJ.Y, BCJ.f
    h, r_d, r_s     = BCJ.h, BCJ.r_d, BCJ.r_s
    H, R_d, R_s     = BCJ.H, BCJ.R_d, BCJ.R_s
    α__, αₜᵣ__, κ   = BCJ.α__, BCJ.αₜᵣ__, BCJ.κ
    β               = BCJ.β
    # timestep calculations
    for i ∈ range(2, BCJ.N + 1)
        α_mag = sum(α__[1:3, i-1] .^ 2.) + 2sum(α__[4:6, i-1] .^ 2.)


        # trial guesses: ISVs (from recovery) and stress
        recovery    = Δt * (r_d * ϵ_dot_effective + r_s) * α_mag  # recovery for alpha (kinematic hardening)
        Recovery    = Δt * (R_d * ϵ_dot_effective + R_s) * κ[i-1] # recovery for kappa (isotropic hardening)
        αₜᵣ__      .= α__[:, i-1] .* (1 - recovery)
        κₜᵣ         = κ[i-1] * (1 - Recovery)

        ## trial stress guess
        σₜᵣ__      .= σ__[:, i-1] + (2μ .* Δϵ)           # trial stress
        ξ__[:, i]  .= σₜᵣ__ - αₜᵣ__                 # trial overstress original
        # ξ__          .= σₜᵣ__ - sqrt23 .* αₜᵣ__   # trial overstress FIT
        ξ_mag       = √(sum(ξ__[1:3, i] .^ 2.) + 2sum(ξ__[4:6, i] .^ 2.))



        # ----------------------------------- #
        ###   ---   YIELD CRITERION   ---   ###
        # ----------------------------------- #
        flow_rule = ξ_mag - κₜᵣ - β         # same as vumat20
        # Crit = Xi_mag - (Katr + β) #changed to FIT
        if flow_rule <= 0.      # elastic
            # trial guesses are correct
            α__[:, i]  .= αₜᵣ__
            κ[i]        = κₜᵣ
            σ__[:, i]  .= σₜᵣ__
            ϵₚ__[:, i] .= ϵₚ__[:, i-1]
            ϵ__[:, i]  .= ϵ__[:, i-1] + Δϵ
        else                    # plastic
            # Radial Return
            Δγ          = flow_rule / (2μ + 2(h + H) / 3)     # original
            n           = ξ__[:, i] ./ ξ_mag
            σ__[:, i]  .= σₜᵣ__ - (2μ * Δγ) .* n
            α__[:, i]  .= αₜᵣ__ + ( h * Δγ) .* n
            κ[i]        = κₜᵣ   + (H * Δγ)  # original
            ϵₚ__[:, i] .= ϵₚ__[:, i-1] + (Δϵ - ((σ__[:, i] - σ__[:, i-1]) ./ 2μ))
            ϵ__[:, i]  .= ϵ__[:, i-1] + Δϵ
        end
        BCJ.ϵ_dot_plastic__[:, i] .= (f * sinh(V \ (ξ_mag - κ[i] - Y)) / ξ_mag) .* ξ__[:, i]
    end
    return nothing
end

function solve!(BCJ::BCJ_metal_currentconfiguration{DK, <:Real})
    μ               = BCJ.μ
    σ__, σₜᵣ__      = BCJ.σ__, BCJ.σₜᵣ__
    ϵₚ__, ϵ__, Δϵ   = BCJ.ϵₚ__, BCJ.ϵ__, BCJ.Δϵ
    ξ__             = BCJ.ξ__
    Δt              = BCJ.Δt
    ϵ_dot_effective = BCJ.ϵ_dot_effective
    ϵ_dot_plastic__ = BCJ.ϵ_dot_plastic__
    V, Y, f         = BCJ.V, BCJ.Y, BCJ.f
    h, r_d, r_s     = BCJ.h, BCJ.r_d, BCJ.r_s
    H, R_d, R_s     = BCJ.H, BCJ.R_d, BCJ.R_s
    α__, αₜᵣ__, κ   = BCJ.α__, BCJ.αₜᵣ__, BCJ.κ
    β               = BCJ.β
    sqrt23          = √(2 / 3)
    # timestep calculations
    for i ∈ range(2, BCJ.N + 1)
        α_mag = sum(α__[1:3, i-1] .^ 2.) + 2sum(α__[4:6, i-1] .^ 2.)
        # α_mag = sqrt( α_mag * 3./2.)       # match cho
        α_mag = sqrt23 * √α_mag       # match vumat20


        # trial guesses: ISVs (from recovery) and stress
        recovery    = Δt * (r_d * ϵ_dot_effective + r_s) * α_mag  # recovery for alpha (kinematic hardening)
        Recovery    = Δt * (R_d * ϵ_dot_effective + R_s) * κ[i-1] # recovery for kappa (isotropic hardening)
        αₜᵣ__      .= α__[:, i-1] .* (1 - recovery)
        κₜᵣ         = κ[i-1] * (1 - Recovery)

        ## trial stress guess
        σₜᵣ__      .= σ__[:, i-1] + 2μ .* Δϵ           # trial stress
        ξ__[:, i]  .= σₜᵣ__ - (2. / 3.) .* αₜᵣ__       # trial overstress original
        # ξ__          .= σₜᵣ__ - sqrt23 .* αₜᵣ__   # trial overstress FIT
        ξ_mag       = √(sum(ξ__[1:3, i] .^ 2.) + 2sum(ξ__[4:6, i] .^ 2.))



        # ----------------------------------- #
        ###   ---   YIELD CRITERION   ---   ###
        # ----------------------------------- #
        flow_rule = ξ_mag - sqrt23 * (κₜᵣ + β)         # same as vumat20
        # Crit = Xi_mag - (Katr + β) #changed to FIT
        if flow_rule <= 0.      # elastic
            # trial guesses are correct
            α__[:, i]  .= αₜᵣ__
            κ[i]        = κₜᵣ
            σ__[:, i]  .= σₜᵣ__
            ϵₚ__[:, i] .= ϵₚ__[:, i-1]
            ϵ__[:, i]  .= ϵ__[:, i-1] + Δϵ
        else                    # plastic
            # Radial Return
            Δγ          = flow_rule / (2μ + 2(h + H) / 3)     # original
            n           = ξ__[:, i] ./ ξ_mag
            σ__[:, i]  .= σₜᵣ__ - (2μ * Δγ) .* n
            α__[:, i]  .= αₜᵣ__ + ( h * Δγ) .* n
            κ[i]        = κₜᵣ   + (H * sqrt23 * Δγ)  # original
            ϵₚ__[:, i] .= ϵₚ__[:, i-1] + (Δϵ - ((σ__[:, i] - σ__[:, i-1]) ./ 2μ))
            ϵ__[:, i]  .= ϵ__[:, i-1] + Δϵ
        end
        BCJ.ϵ_dot_plastic__[:, i] .= (f * sinh(V \ (ξ_mag - κ[i] - Y)) / ξ_mag) .* ξ__[:, i]
    end
    return nothing
end