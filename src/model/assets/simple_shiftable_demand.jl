"""
    define_simple_shiftable_demand_model!(
        m::JuMP.Model,
        scenario::Scenario,
        demand::Demand,
        sets::Sets,
    )

Sets the decision variables and constraints associated with the simple shiftable demand 
(SSD) model.
"""
function define_simple_shiftable_demand_model!(
    m::JuMP.Model,
    scenario::Scenario,
    demand::Demand,
    sets::Sets,
)
    # Create variables related to simple shiftable demand (SSD)
    define_ssd_variables!(m, sets)

    # Update the expression for net demand
    JuMP.add_to_expression!.(m[:d_net], m[:d_dev_up])
    JuMP.add_to_expression!.(m[:d_net], -1 .* m[:d_dev_dn])

    # Create constraints related to SSD
    define_ssd_upper_bounds!(m, sets)
    define_ssd_interval_balance!(m, sets)
    define_ssd_rolling_balance!(m, scenario, demand, sets)
end

"""
    define_ssd_variables!(m::JuMP.Model, sets::Sets)

Creates decision variables to determine the amount of demand that is deviated from the 
base demand profile. Downward demand deviation corresponds to demand that is curtailed and 
upward demand deviation corresponds to demand that is recovered or met preemptively.
"""
function define_ssd_variables!(m::JuMP.Model, sets::Sets)
    # Set the demand deviation variables for simple shiftable demand
    JuMP.@variable(m, d_dev_dn[t in 1:(sets.num_time_steps)] >= 0)
    JuMP.@variable(m, d_dev_up[t in 1:(sets.num_time_steps)] >= 0)
end

"""
    define_ssd_upper_bounds!(m::JuMP.Model, sets::Sets)

Linear inequality constraints that establish upper bounds on the amount that demand can 
curtail and recover or meet preemptively relative to the base demand profile. The upper 
bound values are nonnegative.
"""
function define_ssd_upper_bounds!(m::JuMP.Model, sets::Sets)
    # Set the upper bounds on the demand deviations
    JuMP.@constraint(
        m,
        ssd_dn_upper_bound[t in 1:(sets.num_time_steps)],
        m[:d_dev_dn][t] <= sets.shift_down_capacity[t]
    )
    JuMP.@constraint(
        m,
        ssd_up_upper_bound[t in 1:(sets.num_time_steps)],
        m[:d_dev_up][t] <= sets.shift_up_capacity[t]
    )
end

"""
    define_ssd_interval_balance!(m::JuMP.Model, sets::Sets)

Linear equality constraint that ensures that all demand deviations are balanced over the 
optimization horizon.
"""
function define_ssd_interval_balance!(m::JuMP.Model, sets::Sets)
    # Ensure demand deviations are balanced over the optimization horizon
    JuMP.@constraint(
        m,
        ssd_interval_balance,
        sum(m[:d_dev_up][t] - m[:d_dev_dn][t] for t = 1:(sets.num_time_steps)) == 0
    )
end

"""
    define_ssd_rolling_balance!(
        m::JuMP.Model,
        scenario::Scenario,
        demand::Demand,
        sets::Sets,
    )

Linear inequality constraint that ensures that all demand deviations that occur within 
rolling windows of a user-defined length are balanced.
"""
function define_ssd_rolling_balance!(
    m::JuMP.Model,
    scenario::Scenario,
    demand::Demand,
    sets::Sets,
)
    # Ensure demand deviations are balanced over the rolling windows of user-defined length
    JuMP.@constraint(
        m,
        ssd_rolling_balance[k in 1:floor(
            Int64,
            sets.num_time_steps - demand.shift_duration * (60 / scenario.interval_length) +
            1,
        )],
        sum(
            m[:d_dev_up][τ] - m[:d_dev_dn][τ] for τ =
                k:floor(
                    Int64,
                    demand.shift_duration * (60 / scenario.interval_length) + k - 1,
                )
        ) >= 0
    )
end

"""
    define_shiftable_demand_variable_cost_objective!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        demand::Demand,
    )

Adds the variable costs associated with shifting demand up or down from the consumer's 
demand profile to the objective function.
"""
function define_shiftable_demand_variable_cost_objective!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    demand::Demand,
)
    # Add the variable cost of deviating from the consumer's demand profile
    JuMP.add_to_expression!(
        obj,
        (scenario.interval_length / 60) *
        sum(demand.shift_down_cost .* m[:d_dev_dn] .+ demand.shift_up_cost .* m[:d_dev_up]),
    )
end
