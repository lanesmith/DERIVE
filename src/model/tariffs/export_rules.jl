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
    # Prevent battery energy storage from exporting to the grid
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
