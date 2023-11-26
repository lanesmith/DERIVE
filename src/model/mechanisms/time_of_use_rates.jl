"""
    define_tou_energy_charge_onjective!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        scenario::Scenario,
        sets::Sets,
    )

Adds a cost to the objective function for the time-of-use (TOU) energy charges. This cost 
is determined by calculating the sum of products of net demand at each time step and TOU 
energy prices at each time step.
"""
function define_tou_energy_charge_objective!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    scenario::Scenario,
    sets::Sets,
)
    # Add time-of-use (TOU) energy charges to the objective function
    JuMP.add_to_expression!(
        obj,
        (scenario.interval_length / 60) * sum(m[:d_net] .* sets.energy_prices),
    )
end

"""
    define_demand_charge_objective!(m::JuMP.Model, obj::Jump.AffExpr, sets::Sets)

Adds a cost to the objective function for the different demand charges. This cost is 
determined by calculating the sum of products of maximum demand for each demand-charge 
period and the maximum demand price for that demand-charge period.
"""
function define_demand_charge_objective!(m::JuMP.Model, obj::JuMP.AffExpr, sets::Sets)
    # Add demand charges to the objective function
    JuMP.add_to_expression!(obj, sum(m[:d_max] .* sets.demand_prices))
end
