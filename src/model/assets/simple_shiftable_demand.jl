"""
    define_simple_shiftable_demand_model!(m::JuMP.Model, demand::Demand, sets::Sets)

Sets the decision variables and constraints associated with the simple shiftable demand 
(SSD) model.
"""
function define_simple_shiftable_demand_model!(m::JuMP.Model, demand::Demand, sets::Sets)
    # Create variables related to simple shiftable demand (SSD)
    define_ssd_variables!(m, sets)

    # Update the expression for net demand
    add_to_expression!(m[:d_net], m[:d_dev])

    # Create constraints related to SSD
    define_ssd_lower_bound!(m, sets)
    define_ssd_upper_bound!(m, sets)
    define_ssd_interval_balance!(m, sets)
    define_ssd_rolling_balance!(m, demand, sets)
end

"""
    define_ssd_variables!(m::JuMP.Model, sets::Sets)

Creates a decision variable to determine the amount of demand that is deviated from the 
base demand profile. Negative demand deviation corresponds to demand that is curtailed and 
positive demand deviation corresponds to demand that is recovered or met preemptively.
"""
function define_ssd_variables!(m::JuMP.Model, sets::Sets)
    # Set the demand deviation variables for simple shiftable demand
    @variable(m, d_dev[t in 1:(sets.num_time_steps)])
end

"""
    define_ssd_lower_bound!(m::JuMP.Model, sets::Sets)

Linear inequality constraint that establishes a lower bound on the amount that demand can 
deviate from the base demand profile. The lower bound values are nonpositive and correspond 
to the amount of demand that can be curtailed during a given time step.
"""
function define_ssd_lower_bound!(m::JuMP.Model, sets::Sets)
    # Set the lower bound on the demand deviations (i.e., demand that can be curtailed)
    @constraint(
        m,
        ssd_lower_bound[t in 1:(sets.num_time_steps)],
        m[:d_dev][t] >= sets.shift_down_capacity[t]
    )
end

"""
    define_ssd_upper_bound!(m::JuMP.Model, sets::Sets)

Linear inequality constraint that establishes an upper bound on the amount that demand can 
deviate from the base demand profile. The upper bound values are nonnegative and correspond 
to the amount of demand that can be recovered or met preemptively during a given time step.
"""
function define_ssd_upper_bound!(m::JuMP.Model, sets::Sets)
    # Set the upper bound on the demand deviations (i.e., demand that can be recovered)
    @constraint(
        m,
        ssd_upper_bound[t in 1:(sets.num_time_steps)],
        m[:d_dev][t] <= sets.shift_up_capacity[t]
    )
end

"""
    define_ssd_interval_balance!(m::JuMP.Model, sets::Sets)

Linear equality constraint that ensures that all demand deviations are balanced over the 
optimization horizon.
"""
function define_ssd_interval_balance!(m::JuMP.Model, sets::Sets)
    # Ensure demand deviations are balanced over the optimization horizon
    @constraint(
        m,
        ssd_interval_balance,
        sum(m[:d_dev][t] for t = 1:(sets.num_time_steps)) == 0
    )
end

"""
    define_ssd_rolling_balance!(m::JuMP.Model, demand::Demand, sets::Sets)

Linear inequality constraint that ensures that all demand deviations that occur within 
rolling windows of a user-defined length are balanced.
"""
function define_ssd_rolling_balance!(m::JuMP.Model, demand::Demand, sets::Sets)
    # Ensure demand deviations are balanced over the rolling windows of user-defined length
    @constraint(
        m,
        ssd_rolling_balance[k in 1:(sets.num_time_steps - demand.shift_duration + 1)],
        sum(m[:d_dev][τ] for τ = k:(demand.shift_duration + k - 1)) >= 0
    )
end
