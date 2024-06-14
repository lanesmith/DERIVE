"""
    store_investment_cost_results(
        m::JuMP.Model,
        scenario::Scenario,
        solar::Solar,
        storage::Storage,
        output_filepath::Union{String,Nothing}=nothing,
    )::Dict{String,Any}

Store and update the Dict of investment cost results used in the simulation. Include values 
from the JuMP optimization model and the Solar and Storage objects. Allows results to be 
saved, if desired.
"""
function store_investment_cost_results(
    m::JuMP.Model,
    scenario::Scenario,
    solar::Solar,
    storage::Storage,
    output_filepath::Union{String,Nothing}=nothing,
)::Dict{String,Any}
    # Initialize the investment cost results
    investment_cost_results = Dict{String,Any}()

    # Store the nominal discount rate
    investment_cost_results["nominal_discount_rate"] = scenario.nominal_discount_rate

    # Store the inflation rate
    investment_cost_results["inflation_rate"] = scenario.inflation_rate

    # Store the real discount rate
    if isnothing(scenario.real_discount_rate)
        if isnothing(scenario.nominal_discount_rate) | isnothing(scenario.inflation_rate)
            investment_cost_results["real_discount_rate"] = scenario.real_discount_rate
        else
            investment_cost_results["real_discount_rate"] =
                (scenario.nominal_discount_rate - scenario.inflation_rate) /
                (1 + scenario.inflation_rate)
        end
    else
        investment_cost_results["real_discount_rate"] = scenario.real_discount_rate
    end

    if solar.enabled
        # Store the solar photovoltaic (PV) capacity
        investment_cost_results["solar_capacity"] = JuMP.value(m[:pv_capacity])

        # Store the lifespan of the solar PV system
        investment_cost_results["solar_lifespan"] = solar.lifespan

        # Store the solar capital cost (i.e., $/kW cost)
        investment_cost_results["solar_capital_cost_per_kW"] =
            solar.linked_cost_scaling * solar.capital_cost

        # Store the total capital cost of the solar PV system
        investment_cost_results["total_solar_capital_cost"] =
            solar.linked_cost_scaling * solar.capital_cost * JuMP.value(m[:pv_capacity])

        # Store the capital recovery factor for the solar PV system
        if isnothing(scenario.nominal_discount_rate) | isnothing(scenario.inflation_rate)
            investment_cost_results["solar_capital_recovery_factor"] = 1 / solar.lifespan
        else
            investment_cost_results["solar_capital_recovery_factor"] =
                (
                    investment_cost_results["real_discount_rate"] *
                    (1 + investment_cost_results["real_discount_rate"])^solar.lifespan
                ) / ((1 + investment_cost_results["real_discount_rate"])^solar.lifespan - 1)
        end

        # Store the amortized capital cost of the solar PV system
        investment_cost_results["amortized_solar_capital_cost"] =
            investment_cost_results["solar_capital_recovery_factor"] *
            solar.linked_cost_scaling *
            solar.capital_cost *
            JuMP.value(m[:pv_capacity])

        # Store the solar O&M cost (i.e., $/kW-yr cost)
        investment_cost_results["solar_o&m_cost_per_kW_per_year"] =
            solar.linked_cost_scaling * solar.fixed_om_cost

        # Store the total O&M cost of the solar PV system for one year
        investment_cost_results["solar_o&m_cost"] =
            solar.linked_cost_scaling * solar.fixed_om_cost * JuMP.value(m[:pv_capacity])

        if solar.investment_tax_credit > 0.0
            # Store the solar investment tax credit (ITC) percentage
            investment_cost_results["solar_itc_percent"] = solar.investment_tax_credit

            # Store the total solar ITC
            investment_cost_results["total_solar_itc_amount"] =
                solar.investment_tax_credit *
                solar.linked_cost_scaling *
                solar.capital_cost *
                JuMP.value(m[:pv_capacity])

            # Store the amortized solar ITC
            investment_cost_results["amortized_solar_ITC_amount"] =
                investment_cost_results["solar_capital_recovery_factor"] *
                solar.investment_tax_credit *
                solar.linked_cost_scaling *
                solar.capital_cost *
                JuMP.value(m[:pv_capacity])
        end
    end

    if storage.enabled
        # Store the total battery energy storage (BES) power capacity
        investment_cost_results["storage_capacity"] = JuMP.value(m[:bes_power_capacity])

        # Store the lifespan of the BES system
        investment_cost_results["storage_lifespan"] = storage.lifespan

        # Store the BES duration (in hours)
        investment_cost_results["storage_duration"] = storage.duration

        # Store the storage capital cost (i.e., $/kW cost for a specific storage duration)
        investment_cost_results["storage_capital_cost_per_kW"] =
            storage.linked_cost_scaling * storage.power_capital_cost

        # Store the total capital cost of the BES system
        investment_cost_results["total_storage_capital_cost"] =
            storage.linked_cost_scaling *
            storage.power_capital_cost *
            JuMP.value(m[:bes_power_capacity])

        # Store the capital recovery factor for the BES system
        if isnothing(scenario.nominal_discount_rate) | isnothing(scenario.inflation_rate)
            investment_cost_results["storage_capital_recovery_factor"] =
                1 / storage.lifespan
        else
            investment_cost_results["storage_capital_recovery_factor"] =
                (
                    investment_cost_results["real_discount_rate"] *
                    (1 + investment_cost_results["real_discount_rate"])^storage.lifespan
                ) /
                ((1 + investment_cost_results["real_discount_rate"])^storage.lifespan - 1)
        end

        # Store the amortized capital cost of the BES system
        investment_cost_results["amortized_storage_capital_cost"] =
            investment_cost_results["storage_capital_recovery_factor"] *
            storage.linked_cost_scaling *
            storage.power_capital_cost *
            JuMP.value(m[:bes_power_capacity])

        # Store the storage O&M cost (i.e., $/kW-yr cost)
        investment_cost_results["storage_o&m_cost_per_kW_per_year"] =
            storage.linked_cost_scaling * storage.fixed_om_cost

        # Store the total O&M cost of the BES system for one year
        investment_cost_results["storage_o&m_cost"] =
            storage.linked_cost_scaling *
            storage.fixed_om_cost *
            JuMP.value(m[:bes_power_capacity])

        if storage.investment_tax_credit > 0.0
            # Store the storage ITC percentage
            investment_cost_results["storage_itc_percent"] = storage.investment_tax_credit

            # Store the total storage ITC
            investment_cost_results["total_storage_itc_amount"] =
                storage.investment_tax_credit *
                storage.linked_cost_scaling *
                storage.power_capital_cost *
                JuMP.value(m[:bes_power_capacity])

            # Store the amortized storage ITC
            investment_cost_results["amortized_storage_ITC_amount"] =
                investment_cost_results["storage_capital_recovery_factor"] *
                storage.investment_tax_credit *
                storage.linked_cost_scaling *
                storage.power_capital_cost *
                JuMP.value(m[:bes_power_capacity])
        end
    end

    # Save the electricity bill results, if desired
    if !isnothing(output_filepath)
        CSV.write(
            joinpath(output_filepath, "investment_cost_results.csv"),
            investment_cost_results;
            header=["parameter", "value"],
        )
    end

    # Return the investment cost results
    return investment_cost_results
end
