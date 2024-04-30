"""
    define_sheddable_demand_model!(m::JuMP.Model, sets::Sets)

Sets the decision variables and constraints associated with the sheddable demand model.
"""
function define_sheddable_demand_model!(m::JuMP.Model, sets::Sets)
    # Create variables related to sheddable demand
    define_sheddable_demand_variables!(m, sets)

    # Update the expression for net demand
    JuMP.add_to_expression!.(m[:d_net], -1 .* m[:d_shed])

    # Create constraints related to sheddable demand
    define_sheddable_demand_upper_bounds!(m, sets)
end

"""
    define_sheddable_demand_variables!(m::JuMP.Model, sets::Sets)

Creates a decision variable to determine the amount of demand that is shed from the base
demand profile.
"""
function define_sheddable_demand_variables!(m::JuMP.Model, sets::Sets)
    # Set the demand deviation variable for sheddable demand
    JuMP.@variable(m, d_shed[t in 1:(sets.num_time_steps)] >= 0)
end

"""
    define_sheddable_demand_upper_bounds!(m::JuMP.Model, sets::Sets)

Linear inequality constraint that establishes upper bounds on the amount that demand can 
curtail relative to the base demand profile.
"""
function define_sheddable_demand_upper_bounds!(m::JuMP.Model, sets::Sets)
    # Set the upper bounds on the demand deviations
    JuMP.@constraint(
        m,
        sheddable_demand_upper_bound[t in 1:(sets.num_time_steps)],
        m[:d_shed][t] <= sets.demand[t]
    )
end

"""
    define_sheddable_demand_variable_cost_objective!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        demand::Demand,
    )

Adds the variable costs associated with shedding demand from the consumer's demand profile 
to the objective function.
"""
function define_sheddable_demand_variable_cost_objective!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    demand::Demand,
)
    # Add the variable cost of deviating from the consumer's demand profile
    JuMP.add_to_expression!(
        obj,
        (scenario.interval_length / 60) * sum(demand.value_of_lost_load .* m[:d_shed]),
    )
end
