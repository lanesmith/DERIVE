"""
    calculate_electricity_bill(
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
        storage::Storage,
        time_series_results::DataFrames.DataFrame,
    )::Dict

Calculates the total electricity bill using input data and results from the simulation. 
Provides bill components in addition to the total electricity bill.
"""
function calculate_electricity_bill(
    scenario::Scenario,
    tariff::Tariff,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    time_series_results::DataFrames.DataFrame,
)::Dict
    # Initialize the electricity bill results
    bill_results = Dict{String,Any}()

    # Calculate the total energy charge
    bill_results["energy_charge"] =
        sum(time_series_results[!, "net_demand"] .* tariff.energy_prices[!, "rates"])

    # Initialize the cost of the total electricity bill
    bill_results["total_charge"] = bill_results["energy_charge"]

    # Calculate the total demand charge, if applicable
    if !isnothing(tariff.demand_prices)
        bill_results["demand_charge"] = sum(
            v * maximum(tariff.demand_mask[!, k] .* time_series_results[!, "net_demand"])
            for (k, v) in tariff.demand_prices
        )

        # Update the cost of the total electricity bill
        bill_results["total_charge"] += bill_results["demand_charge"]
    end

    # Calculate the total revenue from net energy metering (NEM), if applicable
    if tariff.nem_enabled
        # Calculate NEM revenue
        bill_results["nem_revenue"] =
            sum(time_series_results[!, "net_exports"] .* tariff.nem_prices[!, "rates"])

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
