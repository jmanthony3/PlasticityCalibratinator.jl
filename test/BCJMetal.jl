using PlasticityBase
using BammannChiesaJohnsonPlasticity

function bcjmetalcalibration_kernel(test_data, test_cond, incnum, istate, params, i, ISV_Model)::NamedTuple
    kS          = 1     # default tension component
    if istate == 2
        kS      = 4     # select torsion component
    end
    emax        = maximum(test_data["Data_E"][i])
    println("Setup: emax for set ", i, " = ", emax)
    bcj_loading     = BCJMetalStrainControl(
        test_cond["Temp"][i], test_cond["StrainRate"][i],
        emax, incnum, istate, params)
    bcj_configuration   = referenceconfiguration(ISV_Model, bcj_loading)
    bcj_reference       = bcj_configuration[1]
    bcj_current         = bcj_configuration[2]
    bcj_history         = bcj_configuration[3]
    solve!(bcj_current, bcj_history)
    println("Solved: emax for set ", i, " = ", maximum(bcj_history.ϵ__))
    ϵ__         = bcj_history.ϵ__
    σ__         = bcj_history.σ__
    α__         = bcj_history.α__
    κ           = bcj_history.κ

    # pull only the relevant (tension/torsion) strain being evaluated:
    ϵ       = ϵ__[kS, :]
    σ       = σ__[kS, :]
    σvM     = symmetricvonMises(σ__)
    α       = α__[kS, :]
    return (ϵ=ϵ, σ=σ, σvM=σvM, α=α, κ=κ)
end