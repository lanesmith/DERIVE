"""
    calculate_electricity_bill(
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
        storage::Storage,
        time_series_results::DataFrames.DataFrame,
    )

Calculates the total electricity bill using input data and results from the simulation. 
Provides bill components in addition to the total electricity bill.
"""
function calculate_electricity_bill(
    scenario::Scenario,
    tariff::Tariff,
    solar::Solar,
    storage::Storage,
    time_series_results::DataFrames.DataFrame,
)
    # Initialize the electricity bill results
    bill_results = Dict{String,Any}()

    # Calculate the net demand
    net_demand = time_series_results[!, "demand"]
    if solar.enabled
        net_demand -= time_series_results[!, "pv_generation_btm"]
    end
    if storage.enabled
        net_demand +=
            time_series_results[!, "bes_charging"] -
            time_series_results[!, "bes_discharging_btm"]
    end

    # Calculate the total energy charge
    bill_results["energy_charge"] = sum(net_demand .* tariff.energy_prices[!, "rates"])

    # Initialize the cost of the total electricity bill
    bill_results["total_charge"] = bill_results["energy_charge"]

    # Calculate the total demand charge, if applicable
    if !isnothing(tariff.demand_prices)
        bill_results["demand_charge"] = sum(
            v * maximum(tariff.demand_mask[!, k] .* net_demand) for
            (k, v) in tariff.demand_prices
        )

        # Update the cost of the total electricity bill
        bill_results["total_charge"] += bill_results["demand_charge"]
    end

    # Calculate the total revenue from net energy metering (NEM), if applicable
    if tariff.nem_enabled
        # Calculate the net exports
        net_exports = zeros(length(net_demand))
        if solar.enabled
            net_exports += time_series_results[!, "pv_generation_export"]
        end
        if storage.enabled & !storage.nonexport
            net_exports += time_series_results[!, "bes_discharging_export"]
        end

        # Calculate NEM revenue
        bill_results["nem_revenue"] = sum(net_exports .* tariff.nem_prices[!, "rates"])

        # Update the cost of the total electricity bill
        bill_results["total_charge"] -= bill_results["nem_revenue"]
    end

    # Calculate the customer charge, if applicable
    if collect(values(tariff.customer_charge)) != zeros(length(tariff.customer_charge))
        bill_results["customer_charge"] = 0
        for (k, v) in tariff.customer_charge
            if k == "daily"
                bill_results["customer_charge"] += Dates.daysinyear(scenario.year) * v
            elseif k == "monthly"
                bill_results["customer_charge"] += 12 * v
            end
        end

        # Update the cost of the total electricity bill
        bill_results["total_charge"] += bill_results["customer_charge"]
    end

    # Return the electricity bill results
    return bill_results
end
