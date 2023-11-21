"""
    define_bes_nonimport_constraint!(m::JuMP.Model, solar::Solar, sets::Sets)

Linear inequality constraint that prevents battery energy storage (BES) from importing 
electricity from the grid. If a solar photovoltaic (PV) system is included, the BES 
charging power cannot be greater that the solar PV generation at a given time, if enabled. 
If a solar PV system is not included, a error is raised since the BES would not be able to 
charge at all, which would be akin to storage not being enabled, something that a user 
would likely have intended to specify elsewhere.
"""
function define_bes_nonimport_constraint!(m::JuMP.Model, solar::Solar, sets::Sets)
    # Prevent the battery energy storage from charging with grid-provided electricity
    if solar.enabled
        # Limits BES charging power to be no greater than PV generation
        JuMP.@constraint(
            m,
            bes_nonimport_constraint[t in 1:(sets.num_time_steps)],
            m[:p_cha][t] <= m[:p_pv_btm][t]
        )
    else
        # BES is unable to charge at all
        raise(
            ErrorException(
                "With no PV system, the battery energy storage is unable to charge under " *
                "a nonimport constraint. Please try again.",
            ),
        )
    end
end

"""
    define_net_demand_and_exports_linkage!(
        m::JuMP.Model,
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
    solar::Solar,
    storage::Storage,
    sets::Sets,
)
    # Define the binary variable that indicates whether if net demand equals zero
    JuMP.@variable(m, ζ[t in 1:(sets.num_time_steps)], Bin)

    # Define the constraint that defines the binary variable    
    JuMP.@constraint(
        m,
        net_demand_and_exports_linkage_constraint[t in 1:(sets.num_time_steps)],
        ζ[t] => {m[:d_net][t] == 0},
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
