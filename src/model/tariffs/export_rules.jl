"""
    define_nonexport_constraint!(
        m::JuMP.Model,
        tariff::Tariff,
        solar::Solar,
        sets::Sets,
    )

Linear inequality constraint that prevents battery energy storage (BES) from exporting to 
the grid. If a solar photovoltaic (PV) system is included, exports cannot be greater than 
the solar PV generation at a given time, thereby allowing net energy metering to occur, if 
enabled.
"""
function define_nonexport_constraint!(
    m::JuMP.Model,
    tariff::Tariff,
    solar::Solar,
    sets::Sets,
)
    # Prevent battery energy storage and flexible loads from exporting to the grid
    if tariff.nem_enabled & solar.enabled
        # Limit exports to be no greater than PV generation (i.e., allow net metering)
        @constraint(
            m,
            nonexport_constraint[t in 1:(sets.num_time_steps)],
            m[:d_net][t] >= -1 * m[:p_pv][t]
        )
    else
        # No exports allowed
        @constraint(
            m,
            nonexport_constraint[t in 1:(sets.num_time_steps)],
            m[:d_net][t] >= 0
        )
    end
end

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
        @constraint(
            m,
            bes_nonimport_constraint[t in 1:(sets.num_time_steps)],
            m[:p_cha][t] <= m[:p_pv][t]
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
