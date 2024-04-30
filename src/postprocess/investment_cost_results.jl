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

    if solar.enabled
        # Store the solar photovoltaic (PV) capacity
        investment_cost_results["solar_capacity"] = JuMP.value(m[:pv_capacity])

        # Store the solar capital cost (i.e., $/kW cost)
        investment_cost_results["solar_capital_cost_per_kW"] = solar.capital_cost

        # Store the total capital cost of the solar PV system
        investment_cost_results["total_solar_capital_cost"] =
            solar.capital_cost * JuMP.value(m[:pv_capacity])

        # Store the amortized capital cost of the solar PV system
        if isnothing(scenario.real_discount_rate)
            if isnothing(scenario.nominal_discount_rate) |
               isnothing(scenario.inflation_rate)
                investment_cost_results["amortized_solar_capital_cost"] =
                    solar.capital_cost * JuMP.value(m[:pv_capacity]) / solar.lifespan
            else
                real_discount_rate =
                    (scenario.nominal_discount_rate - scenario.inflation_rate) /
                    (1 + scenario.inflation_rate)
                investment_cost_results["amortized_solar_capital_cost"] =
                    (
                        (real_discount_rate * (1 + real_discount_rate)^solar.lifespan) /
                        ((1 + real_discount_rate)^solar.lifespan - 1)
                    ) *
                    solar.capital_cost *
                    JuMP.value(m[:pv_capacity])
            end
        else
            investment_cost_results["amortized_solar_capital_cost"] =
                (
                    (
                        scenario.real_discount_rate *
                        (1 + scenario.real_discount_rate)^solar.lifespan
                    ) / ((1 + scenario.real_discount_rate)^solar.lifespan - 1)
                ) *
                solar.capital_cost *
                JuMP.value(m[:pv_capacity])
        end

        # Store the solar O&M cost (i.e., $/kW-yr cost)
        investment_cost_results["solar_o&m_cost_per_kW_per_year"] = solar.fixed_om_cost

        # Store the total O&M cost of the solar PV system for one year
        investment_cost_results["solar_o&m_cost"] =
            solar.fixed_om_cost * JuMP.value(m[:pv_capacity])

        if solar.investment_tax_credit > 0.0
            # Store the solar investment tax credit (ITC) percentage
            investment_cost_results["solar_itc_percent"] = solar.investment_tax_credit

            # Store the total solar ITC
            investment_cost_results["total_solar_itc_amount"] =
                solar.investment_tax_credit *
                solar.capital_cost *
                JuMP.value(m[:pv_capacity])

            # Store the amortized solar ITC
            if isnothing(scenario.real_discount_rate)
                if isnothing(scenario.nominal_discount_rate) |
                   isnothing(scenario.inflation_rate)
                    investment_cost_results["amortized_solar_ITC_amount"] =
                        solar.investment_tax_credit *
                        solar.capital_cost *
                        JuMP.value(m[:pv_capacity]) / solar.lifespan
                else
                    real_discount_rate =
                        (scenario.nominal_discount_rate - scenario.inflation_rate) /
                        (1 + scenario.inflation_rate)
                    investment_cost_results["amortized_solar_ITC_amount"] =
                        (
                            (real_discount_rate * (1 + real_discount_rate)^solar.lifespan) /
                            ((1 + real_discount_rate)^solar.lifespan - 1)
                        ) *
                        solar.investment_tax_credit *
                        solar.capital_cost *
                        JuMP.value(m[:pv_capacity])
                end
            else
                investment_cost_results["amortized_solar_ITC_amount"] =
                    (
                        (
                            scenario.real_discount_rate *
                            (1 + scenario.real_discount_rate)^solar.lifespan
                        ) / ((1 + scenario.real_discount_rate)^solar.lifespan - 1)
                    ) *
                    solar.investment_tax_credit *
                    solar.capital_cost *
                    JuMP.value(m[:pv_capacity])
            end
        end
    end

    if storage.enabled
        # Store the total battery energy storage (BES) power capacity
        investment_cost_results["storage_capacity"] = JuMP.value(m[:bes_power_capacity])

        # Store the BES duration (in hours)
        investment_cost_results["storage_duration"] = storage.duration

        # Store the storage capital cost (i.e., $/kW cost for a specific storage duration)
        investment_cost_results["storage_capital_cost_per_kW"] = storage.power_capital_cost

        # Store the total capital cost of the BES system
        investment_cost_results["total_storage_capital_cost"] =
            storage.power_capital_cost * JuMP.value(m[:bes_power_capacity])

        # Store the amortized capital cost of the BES system
        if isnothing(scenario.real_discount_rate)
            if isnothing(scenario.nominal_discount_rate) |
               isnothing(scenario.inflation_rate)
                investment_cost_results["amortized_storage_capital_cost"] =
                    storage.power_capital_cost * JuMP.value(m[:bes_power_capacity]) /
                    storage.lifespan
            else
                real_discount_rate =
                    (scenario.nominal_discount_rate - scenario.inflation_rate) /
                    (1 + scenario.inflation_rate)
                investment_cost_results["amortized_storage_capital_cost"] =
                    (
                        (real_discount_rate * (1 + real_discount_rate)^storage.lifespan) /
                        ((1 + real_discount_rate)^storage.lifespan - 1)
                    ) *
                    storage.power_capital_cost *
                    JuMP.value(m[:bes_power_capacity])
            end
        else
            investment_cost_results["amortized_storage_capital_cost"] =
                (
                    (
                        scenario.real_discount_rate *
                        (1 + scenario.real_discount_rate)^storage.lifespan
                    ) / ((1 + scenario.real_discount_rate)^storage.lifespan - 1)
                ) *
                storage.power_capital_cost *
                JuMP.value(m[:bes_power_capacity])
        end

        # Store the storage O&M cost (i.e., $/kW-yr cost)
        investment_cost_results["storage_o&m_cost_per_kW_per_year"] = storage.fixed_om_cost

        # Store the total O&M cost of the BES system for one year
        investment_cost_results["storage_o&m_cost"] =
            storage.fixed_om_cost * JuMP.value(m[:bes_power_capacity])

        if storage.investment_tax_credit > 0.0
            # Store the storage ITC percentage
            investment_cost_results["storage_itc_percent"] = storage.investment_tax_credit

            # Store the total storage ITC
            investment_cost_results["total_storage_itc_amount"] =
                storage.investment_tax_credit *
                storage.power_capital_cost *
                JuMP.value(m[:bes_power_capacity])

            # Store the amortized storage ITC
            if isnothing(scenario.real_discount_rate)
                if isnothing(scenario.nominal_discount_rate) |
                   isnothing(scenario.inflation_rate)
                    investment_cost_results["amortized_storage_ITC_amount"] =
                        storage.investment_tax_credit *
                        storage.power_capital_cost *
                        JuMP.value(m[:bes_power_capacity]) / storage.lifespan
                else
                    real_discount_rate =
                        (scenario.nominal_discount_rate - scenario.inflation_rate) /
                        (1 + scenario.inflation_rate)
                    investment_cost_results["amortized_storage_ITC_amount"] =
                        (
                            (
                                real_discount_rate *
                                (1 + real_discount_rate)^storage.lifespan
                            ) / ((1 + real_discount_rate)^storage.lifespan - 1)
                        ) *
                        storage.investment_tax_credit *
                        storage.power_capital_cost *
                        JuMP.value(m[:bes_power_capacity])
                end
            else
                investment_cost_results["amortized_storage_ITC_amount"] =
                    (
                        (
                            scenario.real_discount_rate *
                            (1 + scenario.real_discount_rate)^storage.lifespan
                        ) / ((1 + scenario.real_discount_rate)^storage.lifespan - 1)
                    ) *
                    storage.investment_tax_credit *
                    storage.power_capital_cost *
                    JuMP.value(m[:bes_power_capacity])
            end
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
