"""
    calculate_electricity_bill(
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
        time_series_results::DataFrames.DataFrame,
        output_filepath::Union{String,Nothing}=nothing,
    )::Dict{String,Any}

Calculates the total electricity bill using input data and results from the simulation. 
Provides bill components in addition to the total electricity bill.
"""
function calculate_electricity_bill(
    scenario::Scenario,
    tariff::Tariff,
    solar::Solar,
    time_series_results::DataFrames.DataFrame,
    output_filepath::Union{String,Nothing}=nothing,
)::Dict{String,Any}
    # Initialize the electricity bill results
    bill_results = Dict{String,Any}()

    # Determine the time-of-use energy charge scaling
    if tariff.tou_energy_charge_scaling > 0.0
        tou_energy_charge_scaling =
            tariff.tou_energy_charge_scaling .*
            tariff.tou_energy_charge_scaling_indicator[!, "indicators"]
        replace!(tou_energy_charge_scaling, 0.0 => 1.0)
    else
        tou_energy_charge_scaling =
            tariff.tou_energy_charge_scaling_indicator[!, "indicators"]
        for i in eachindex(tou_energy_charge_scaling)
            if tou_energy_charge_scaling[i] == 1.0
                tou_energy_charge_scaling[i] *= tariff.tou_energy_charge_scaling
            else
                tou_energy_charge_scaling[i] = 1.0
            end
        end
    end

    # Calculate the total energy charge
    bill_results["energy_charge"] =
        tariff.all_charge_scaling *
        tariff.energy_charge_scaling *
        sum(
            time_series_results[!, "net_demand"] .* tou_energy_charge_scaling .*
            tariff.energy_prices[!, "rates"],
        )

    # Initialize the cost of the total electricity bill
    bill_results["total_charge"] = bill_results["energy_charge"]

    # Calculate the total demand charge, if applicable
    if !isnothing(tariff.demand_prices)
        bill_results["demand_charge"] =
            tariff.all_charge_scaling *
            tariff.demand_charge_scaling *
            sum(
                v *
                maximum(tariff.demand_mask[!, k] .* time_series_results[!, "net_demand"])
                for (k, v) in tariff.demand_prices
            )

        # Update the cost of the total electricity bill
        bill_results["total_charge"] += bill_results["demand_charge"]
    end

    # Calculate the total non-bypassable charges (a subset of the total energy charge) and 
    # the total revenue from net energy metering (NEM), if applicable
    if tariff.nem_enabled & solar.enabled
        if tariff.nem_version == 1
            # Calculate NEM revenue
            bill_results["nem_revenue"] =
                tariff.all_charge_scaling *
                tariff.energy_charge_scaling *
                sum(
                    time_series_results[!, "net_exports"] .* tou_energy_charge_scaling .*
                    tariff.nem_prices[!, "rates"],
                )

            # Update the cost of the total electricity bill
            bill_results["total_charge"] -=
                min(bill_results["nem_revenue"], bill_results["energy_charge"])
        elseif tariff.nem_version == 2
            # Calculate the non-bypassable charges
            bill_results["non_bypassable_charge"] =
                tariff.non_bypassable_charge * sum(time_series_results[!, "net_demand"])

            # Calculate NEM revenue
            bill_results["nem_revenue"] = sum(
                time_series_results[!, "net_exports"] .* (
                    tariff.all_charge_scaling .* tariff.energy_charge_scaling .*
                    tou_energy_charge_scaling .*
                    (tariff.nem_prices[!, "rates"] .+ tariff.non_bypassable_charge)
                ),
            )

            # Update the cost of the total electricity bill
            bill_results["total_charge"] -= min(
                bill_results["nem_revenue"],
                bill_results["energy_charge"] - bill_results["non_bypassable_charge"],
            )
        elseif tariff.nem_version == 3
            # Calculate the non-bypassable charges
            bill_results["non_bypassable_charge"] =
                tariff.non_bypassable_charge * sum(time_series_results[!, "net_demand"])

            # Calculate NEM revenue
            if scenario.optimization_horizon == "YEAR"
                bill_results["nem_revenue"] = sum(
                    time_series_results[!, "net_exports"] .* tariff.nem_prices[!, "rates"]
                )
            else
                bill_results["nem_revenue"] = sum(
                    time_series_results[!, "net_exports"] .*
                    (tariff.nem_prices[!, "rates"] .+ tariff.non_bypassable_charge),
                )
            end

            # Update the cost of the total electricity bill
            bill_results["total_charge"] -= min(
                bill_results["nem_revenue"],
                bill_results["energy_charge"] - bill_results["non_bypassable_charge"],
            )
        end
    end

    # Calculate the customer charge, if applicable
    if collect(values(tariff.customer_charge)) != zeros(length(tariff.customer_charge))
        bill_results["customer_charge"] = 0
        for (k, v) in tariff.customer_charge
            if k == "daily"
                bill_results["customer_charge"] +=
                    tariff.all_charge_scaling * Dates.daysinyear(scenario.year) * v
            elseif k == "monthly"
                bill_results["customer_charge"] += tariff.all_charge_scaling * 12 * v
            end
        end

        # Update the cost of the total electricity bill
        bill_results["total_charge"] += bill_results["customer_charge"]
    end

    # Save the electricity bill results, if desired
    if !isnothing(output_filepath)
        CSV.write(
            joinpath(output_filepath, "electricity_bill_results.csv"),
            bill_results;
            header=["parameter", "value"],
        )
    end

    # Return the electricity bill results
    return bill_results
end
