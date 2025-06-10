"""
    define_tiered_energy_rates_tier_constraints!(
        m::JuMP.Model,
        scenario::Scenario,
        sets::Sets,
    )

Linear inequality constraint and linear equality constraint for the tiered energy rates. 
The inequality constraints place an upper bound on the variables that correspond to the 
energy consumption over the different tiers. These upper bounds are determined by taking 
the difference between the upper and lower bounds of the different tiers. The equality 
constraints ensure that monthly consumption for each tier equals the total monthly net 
demand.
"""
function define_tiered_energy_rates_tier_constraints!(
    m::JuMP.Model,
    scenario::Scenario,
    sets::Sets,
)
    # Determine the number of net consumption tier quantities that require an upper bound.
    # If the last tier has an upper bound of Inf, that net consumption tier quantity does 
    # not need an upper bound
    num_tier_ub_constraints = sets.num_tiered_energy_rates_tiers
    if Inf in sets.tiered_energy_rates[sets.num_tiered_energy_rates_tiers]["bounds"]
        num_tier_ub_constraints -= 1
    end

    # Set the upper bounds, as necessary, for each net consumption tier quantity
    JuMP.@constraint(
        m,
        tiered_energy_rates_tiers_upper_bounds[n in 1:num_tier_ub_constraints],
        m[:e_tier][n] <= (
            sets.tiered_energy_rates[n]["bounds"][2] -
            sets.tiered_energy_rates[n]["bounds"][1]
        )
    )

    # Ensure that the sum of the net consumption tier quantities equals the sum of the net 
    # demand
    JuMP.@constraint(
        m,
        tiered_energy_rates_tiers_equality,
        sum(m[:e_tier]) == (scenario.interval_length / 60) * sum(m[:d_net])
    )
end

"""
    define_tiered_energy_rates_objective!(m::JuMP.Model, obj::JuMP.AffExpr, sets::Sets)

Adds a charge to the objective function for the tiered energy rates. This additional charge 
is the sum of the products of the total energy consumption in a tier and the price of 
consuming energy while in that tier.
"""
function define_tiered_energy_rates_objective!(m::JuMP.Model, obj::JuMP.AffExpr, sets::Sets)
    # Add the tiered energy rate costs to the objective function
    JuMP.add_to_expression!(
        obj,
        sum(
            m[:e_tier][n] * sets.tiered_energy_rates[n]["price"] for
            n = 1:(sets.num_tiered_energy_rates_tiers)
        ),
    )
end
