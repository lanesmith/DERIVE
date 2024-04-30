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

Defines an indicator variable and constraint that links export decisions by solar 
photovoltaics (PVs) and battery energy storage to the value of the net demand. Namely, per 
net energy metering rules, only excess behind-the-meter generation can be exported, meaning 
that a consumer's net demand must equal zero before exports can occur. The binary indicator 
variable equals one when net demand is les than or equal to zero and equals zero otherwise. 
The linkage constraint sets a bound on the total exports expression.
"""
function define_net_demand_and_exports_linkage!(
    m::JuMP.Model,
    scenario::Scenario,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Determine the time steps in which export prices are greater than energy prices
    time_steps_subset =
        filter(t -> sets.nem_prices[t] > sets.energy_prices[t], 1:(sets.num_time_steps))

    if !isempty(time_steps_subset)
        # Define the mapping between the indicator variable indices and the other 
        # time-related parameters
        time_mapping = Dict{Int64,Int64}(
            t => time_steps_subset[t] for t in eachindex(time_steps_subset)
        )

        # Define the binary variable that indicates if net demand is less than or equal to zero
        JuMP.@variable(m, ζ_net[t in eachindex(time_steps_subset)], binary = true)

        # Define the constraint that defines the indicator variable    
        JuMP.@constraint(
            m,
            net_demand_and_exports_linkage_constraint[t in eachindex(time_steps_subset)],
            ζ_net[t] => {m[:d_net][time_mapping[t]] <= 0},
        )

        # Define the total potential exports capacity
        p_exports_ub = 0
        if solar.enabled
            if (scenario.problem_type == "CEM") & solar.make_investment
                p_exports_ub += solar.maximum_power_capacity
            else
                p_exports_ub += solar.power_capacity
            end
        end
        if storage.enabled & !storage.nonexport
            if (scenario.problem_type == "CEM") & storage.make_investment
                p_exports_ub += storage.maximum_power_capacity
            else
                p_exports_ub += storage.power_capacity
            end
        end

        # Define the constraint that prevents exports if net demand does not equal zero
        JuMP.@constraint(
            m,
            exports_considering_net_demand_upper_bound_constraint[t in eachindex(
                time_steps_subset,
            )],
            m[:p_exports][time_mapping[t]] <= ζ_net[t] * p_exports_ub,
        )
    end
end

"""
    define_pv_capacity_and_exports_linkage!(
        m::JuMP.Model,
        solar::Solar,
        storage::Storage,
        sets::Sets,
    )

Defines an indicator variable and constraint that links export decisions by solar 
photovoltaics (PVs) and battery energy storage to the value of the built PV capacity in 
capacity expansion simulations. Namely, per net energy metering rules, consumers can only 
participate in net energy metering if they have a renewable energy generating facility 
(e.g., solar PVs), meaning that a consumer's ability to export hinges on whether their PV 
capacity is greater than zero. The binary indicator variable equals one when PV capacity is 
less than or equal to zero and equals zero otherwise. The linkage constraint sets a bound 
on the total exports expression.
"""
function define_pv_capacity_and_exports_linkage!(
    m::JuMP.Model,
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Define the binary variable that indicates if PV capacity is less than or equal to zero
    JuMP.@variable(m, ζ_pv, binary = true)

    # Define the constraint that defines the indicator variable    
    JuMP.@constraint(
        m,
        pv_capacity_and_exports_linkage_constraint,
        ζ_pv => {m[:pv_capacity] <= 0},
    )

    # Define the total potential exports capacity
    p_exports_ub = 0
    if solar.enabled
        p_exports_ub += solar.maximum_power_capacity
    end
    if storage.enabled & !storage.nonexport
        p_exports_ub += storage.maximum_power_capacity
    end

    # Define the constraint that prevents exports if PV capacity equals zero
    JuMP.@constraint(
        m,
        exports_considering_pv_capacity_upper_bound_constraint[t in 1:(sets.num_time_steps)],
        m[:p_exports][t] <= (1 - ζ_pv) * p_exports_ub,
    )
end
