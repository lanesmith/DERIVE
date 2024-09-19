"""
    calculate_electricity_bill(
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
        time_series_results::DataFrames.DataFrame,
        tiered_energy_results::Union{Dict,Nothing}=nothing,
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
    tiered_energy_results::Union{Dict,Nothing}=nothing,
    output_filepath::Union{String,Nothing}=nothing,
)::Dict{String,Any}
    # Initialize the electricity bill results
    bill_results = Dict{String,Any}()

    # Determine the time-of-use energy charge scaling
    tou_energy_charge_scaling =
        deepcopy(tariff.tou_energy_charge_scaling_indicator[!, "indicators"])
    for i in eachindex(tou_energy_charge_scaling)
        if tou_energy_charge_scaling[i] == 1.0
            tou_energy_charge_scaling[i] *= tariff.tou_energy_charge_scaling
        elseif tou_energy_charge_scaling[i] in
               range(2.0, length(tariff.months_by_season) + 1.0)
            if tariff.tou_energy_charge_scaling == 1.0
                tou_energy_charge_scaling[i] = 1.0
            else
                # Get the season name
                season_name = sort(collect(keys(tariff.months_by_season)))[floor(
                    Int64,
                    tou_energy_charge_scaling[i] - 1.0,
                )]

                # Find the relevant peak, partial-peak, and off-peak energy prices
                p = retrieve_tou_price(tariff, season_name, "peak")
                pp = retrieve_tou_price(tariff, season_name, "partial-peak")
                op = retrieve_tou_price(tariff, season_name, "off-peak")

                # Find the relative placement of the partial-peak price between the peak 
                # and off-peak prices
                r = (pp - op) / (p - op)

                # Find the related partial-peak scaling term
                tou_energy_charge_scaling[i] =
                    (r * (tariff.tou_energy_charge_scaling * p - op) + op) / pp
            end
        else
            tou_energy_charge_scaling[i] = 1.0
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
                    time_series_results[!, "net_exports"] .* tariff.nem_prices[!, "rates"],
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

    # Calculate the surcharge from the tiered energy rate, if applicable
    if !isnothing(tiered_energy_results)
        # Determine the number of tiers in the tiered energy rate
        # Note: this assumes that each month has the same number of tiers
        num_tiers = length(keys(tariff.energy_tiered_rates[1]))

        # Calculate the surcharge for the different supported optimization horizons
        if scenario.optimization_horizon == "DAY"
            bill_results["tiered_energy_charge"] = sum(
                sum(
                    sum(
                        tariff.energy_tiered_rates[m][b]["price"] *
                        tiered_energy_results[string(m) * "-" * string(d)][b] for
                        b = 1:num_tiers
                    ) for d = 1:Dates.daysinmonth(scenario.year, m)
                ) for m = 1:12
            )
        elseif scenario.optimization_horizon == "MONTH"
            bill_results["tiered_energy_charge"] = sum(
                sum(
                    tariff.energy_tiered_rates[m][b]["price"] *
                    tiered_energy_results[string(m)][b] for b = 1:num_tiers
                ) for m = 1:12
            )
        end

        # Update the cost of the total electricity bill
        bill_results["total_charge"] += bill_results["tiered_energy_charge"]
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
