"""
    define_tiered_energy_rates_variables!(m::JuMP.Model, sets::Sets)

Defines the variables that correspond to the energy consumption over the different tiers 
specified by the utility tariff. These variables are constrained to be nonnegative.
"""
function define_tiered_energy_rates_variables!(m::JuMP.Model, sets::Sets)
    # Set the variables associated with the energy tiered rates
    JuMP.@variable(m, e_tier[n in 1:(sets.num_tiered_energy_rates_tiers)] >= 0)
end

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
    # Set the upper bounds for the tiers
    JuMP.@constraint(
        m,
        tiered_energy_rates_tiers_upper_bounds[n in 1:(sets.num_tiered_energy_rates_tiers)],
        m[:e_tier][n] <= (
            sets.tiered_energy_rates[n]["bounds"][2] -
            sets.tiered_energy_rates[n]["bounds"][1]
        )
    )

    # Ensure that the sum of the tiers is equal to the net demand
    JuMP.@constraint(
        m,
        tiered_energy_rates_tiers_equality[μ in 1:(Dates.month(
            sets.end_date,
        ) - Dates.month(sets.start_date) + 1)],
        sum(
            (sets.tiered_energy_rates[n]["month"] == (μ + Dates.month(start_date) - 1)) ?
            m[:e_tier][n] : 0 for n = 1:(sets.num_tiered_energy_rates_tiers)
        ) ==
        (scenario.interval_length / 60) * sum(
            m[:d_net][t] for t =
                ((Dates.dayofyear(sets.start_date) - 1) * 24 + 1):(Dates.dayofyear(
                    sets.end_date,
                ) * 24)
        )
    )
end

"""
    define_tiered_energy_rates_objective!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        sets::Sets,
    )

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
