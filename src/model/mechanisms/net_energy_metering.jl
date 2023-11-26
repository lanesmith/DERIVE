"""
    define_net_energy_metering_revenue_objective!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        scenario::Scenario,
        sets::Sets,
    )

Adds a revenue (i.e., subtracts a cost) to the objective function for the net energy 
metering (NEM) program. This revenue is determined by calculating the sum of products of 
net demand at each time step and NEM prices at eahc time step. To make it a revenue, this 
sum is multiplied by -1.
"""
function define_net_energy_metering_revenue_objective!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    scenario::Scenario,
    sets::Sets,
)
    # Add revenue from net energy metering (NEM) to the objective function
    JuMP.add_to_expression!(
        obj,
        -1 * (scenario.interval_length / 60) * sum(m[:p_exports] .* sets.nem_prices),
    )
end

"""
    define_net_demand_and_exports_linkage!(
        m::JuMP.Model,
        scenario::Scenario,
        solar::Solar,
        storage::Storage,
        sets::Sets,
    )

Defines a binary indicator and constraint that links export decisions by solar PVs and 
battery energy storage to the value of the net demand. Namely, per net energy metering 
rules, only excess behind-the-meter generation can occur, meaning that a consumer's net 
demand must equal zero before exports can occur. The binary indicator variable equals one 
when net demand is equal to zero and equals zero otherwise. The linkage constraint sets a 
bound on the total exports expression.
"""
function define_net_demand_and_exports_linkage!(
    m::JuMP.Model,
    scenario::Scenario,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Define the binary variable that indicates if net demand equals zero
    JuMP.@variable(
        m,
        ζ[t in 1:(sets.num_time_steps)],
        binary = scenario.binary_net_demand_and_exports_linkage,
    )

    # Add bounds to the indicator variable if it is linear instead of binary
    if !scenario.binary_net_demand_and_exports_linkage
        JuMP.@constraint(
            m,
            net_demand_inidcator_lower_bound[t in 1:(sets.num_time_steps)],
            ζ[t] >= 0
        )
        JuMP.@constraint(
            m,
            net_demand_inidcator_upper_bound[t in 1:(sets.num_time_steps)],
            ζ[t] <= 1
        )
    end

    # Define the constraint that defines the indicator variable    
    JuMP.@constraint(
        m,
        net_demand_and_exports_linkage_constraint[t in 1:(sets.num_time_steps)],
        ζ[t] => {m[:d_net][t] <= 0},
    )

    # Define the total potential exports capacity
    p_exports_ub = 0
    if solar.enabled
        p_exports_ub += solar.power_capacity
    end
    if storage.enabled & !storage.nonexport
        p_exports_ub += storage.power_capacity
    end

    # Define the constraint that prevents exports if net demand does not equal zero
    JuMP.@constraint(
        m,
        exports_upper_bound_constraint[t in 1:(sets.num_time_steps)],
        m[:p_exports][t] <= ζ[t] * p_exports_ub,
    )
end
