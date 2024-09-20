"""
    calculate_electricity_bill(
        scenario::Scenario,
        tariff::Tariff,
        solar::Solar,
        time_series_results::DataFrames.DataFrame,
        tiered_energy_results::Union{Dict,Nothing}=nothing,
        output_filepath::Union{String,Nothing}=nothing,
    )::DataFrames.DataFrame

Calculates the total annual and monthly electricity bills using input data and results from 
the simulation. Provides itemized bill components in addition to the total electricity bill.
"""
function calculate_electricity_bill(
    scenario::Scenario,
    tariff::Tariff,
    solar::Solar,
    time_series_results::DataFrames.DataFrame,
    tiered_energy_results::Union{Dict,Nothing}=nothing,
    output_filepath::Union{String,Nothing}=nothing,
)::DataFrames.DataFrame
    # Initialize the electricity bill results
    bill_results =
        DataFrames.DataFrame(month=push!([Dates.monthname(m) for m = 1:12], "Total"))

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

    # Initialize columns of the DataFrame that correspond to the included bill components
    bill_results[!, "energy_charge"] = zeros(size(bill_results)[1])
    if !isnothing(tiered_energy_results)
        bill_results[!, "tiered_energy_charge"] = zeros(size(bill_results)[1])
    end
    if !isnothing(tariff.demand_prices)
        bill_results[!, "demand_charge"] = zeros(size(bill_results)[1])
    end
    if tariff.nem_enabled & solar.enabled
        bill_results[!, "nem_revenue"] = zeros(size(bill_results)[1])
        if tariff.nem_version in [2, 3]
            bill_results[!, "non_bypassable_charge"] = zeros(size(bill_results)[1])
        end
    end
    if collect(values(tariff.customer_charge)) != zeros(length(tariff.customer_charge))
        bill_results[!, "customer_charge"] = zeros(size(bill_results)[1])
    end
    bill_results[!, "total_charge"] = zeros(size(bill_results)[1])

    # Iterate through each month to determine the monthly charge for each bill component
    for m = 1:12
        # Identify the relevant monthly time steps
        monthly_time_steps = [
            rownumber(time_series_results[r, :]) for
            r = 1:size(time_series_results)[1] if
            Dates.month(time_series_results[r, "timestamp"]) == m
        ]

        # Iterate through the considered electricity bill elements
        for i in names(bill_results)[2:(end - 1)]
            if i == "energy_charge"
                # Calculate the energy charge
                bill_results[m, i] =
                    tariff.all_charge_scaling *
                    tariff.energy_charge_scaling *
                    sum(
                        time_series_results[t, "net_demand"] *
                        tou_energy_charge_scaling[t] *
                        tariff.energy_prices[t, "rates"] for t in monthly_time_steps
                    )
            elseif i == "tiered_energy_charge"
                # Calculate the surcharge in each tier from the tiered energy rate
                # Determine the number of tiers in the tiered energy rate
                # Note: this assumes that each month has the same number of tiers
                num_tiers = length(keys(tariff.energy_tiered_rates[1]))

                # Calculate the surcharge for the different supported optimization horizons
                if scenario.optimization_horizon == "DAY"
                    bill_results[m, i] = sum(
                        sum(
                            tariff.energy_tiered_rates[m][b]["price"] *
                            tiered_energy_results[string(m) * "-" * string(d)][b] for
                            b = 1:num_tiers
                        ) for d = 1:Dates.daysinmonth(scenario.year, m)
                    )
                elseif scenario.optimization_horizon == "MONTH"
                    bill_results[m, i] = sum(
                        tariff.energy_tiered_rates[m][b]["price"] *
                        tiered_energy_results[string(m)][b] for b = 1:num_tiers
                    )
                end
            elseif i == "demand_charge"
                # Calculate the total demand charge
                bill_results[m, i] =
                    tariff.all_charge_scaling *
                    tariff.demand_charge_scaling *
                    sum(
                        v * maximum(
                            tariff.demand_mask[t, k] * time_series_results[t, "net_demand"]
                            for t in monthly_time_steps
                        ) for (k, v) in tariff.demand_prices
                    )
            elseif i == "nem_revenue"
                # Calculate the NEM revenue based on the NEM version
                if tariff.nem_version == 1
                    bill_results[m, i] =
                        tariff.all_charge_scaling *
                        tariff.energy_charge_scaling *
                        sum(
                            time_series_results[t, "net_exports"] *
                            tou_energy_charge_scaling[t] *
                            tariff.nem_prices[t, "rates"] for t in monthly_time_steps
                        )
                elseif tariff.nem_version == 2
                    bill_results[m, i] = sum(
                        time_series_results[t, "net_exports"] * (
                            tariff.all_charge_scaling *
                            tariff.energy_charge_scaling *
                            tou_energy_charge_scaling[t] *
                            (tariff.nem_prices[t, "rates"] + tariff.non_bypassable_charge)
                        ) for t in monthly_time_steps
                    )
                elseif tariff.nem_version == 3
                    if scenario.optimization_horizon == "YEAR"
                        bill_results[m, i] = sum(
                            time_series_results[t, "net_exports"] *
                            tariff.nem_prices[t, "rates"] for t in monthly_time_steps
                        )
                    else
                        bill_results[m, i] = sum(
                            time_series_results[t, "net_exports"] * (
                                tariff.nem_prices[t, "rates"] +
                                tariff.non_bypassable_charge
                            ) for t in monthly_time_steps
                        )
                    end
                end
            elseif i == "non_bypassable_charge"
                # Calculate the non-bypassable charges
                bill_results[m, i] =
                    tariff.non_bypassable_charge *
                    sum(time_series_results[t, "net_demand"] for t in monthly_time_steps)
            elseif i == "customer_charge"
                # Calculate the customer charge
                bill_results[m, i] = 0
                for (k, v) in tariff.customer_charge
                    if k == "daily"
                        bill_results[m, i] +=
                            tariff.all_charge_scaling *
                            Dates.daysinmonth(scenario.year, m) *
                            v
                    elseif k == "monthly"
                        bill_results[m, i] += tariff.all_charge_scaling * v
                    end
                end
            end
        end
    end

    # Determine the annual totals for each bill component, including appropriate 
    # adjustments for programs like NEM
    for i in names(bill_results)[2:(end - 1)]
        if i == "nem_revenue"
            if tariff.nem_version == 1
                bill_results[13, i] = min(
                    sum(bill_results[m, i] for m = 1:12),
                    sum(bill_results[m, "energy_charge"] for m = 1:12),
                )
            elseif tariff.nem_version == 2
                bill_results[13, i] = min(
                    sum(bill_results[m, i] for m = 1:12),
                    (
                        sum(bill_results[m, "energy_charge"] for m = 1:12) -
                        sum(bill_results[m, "non_bypassable_charge"] for m = 1:12)
                    ),
                )
            elseif tariff.nem_version == 3
                bill_results[13, i] = min(
                    sum(bill_results[m, i] for m = 1:12),
                    (
                        sum(bill_results[m, "energy_charge"] for m = 1:12) -
                        sum(bill_results[m, "non_bypassable_charge"] for m = 1:12)
                    ),
                )
            end
        else
            bill_results[13, i] = sum(bill_results[m, i] for m = 1:12)
        end
    end

    # Determine the monthly total electricity bills and annual total electricity bill
    for m = 1:13
        for i in names(bill_results)[2:(end - 1)]
            if i == "nem_revenue"
                bill_results[m, "total_charge"] -= bill_results[m, i]
            elseif i == "non_bypassable_charge"
                continue
            else
                bill_results[m, "total_charge"] += bill_results[m, i]
            end
        end
    end

    # Save the electricity bill results, if desired
    if !isnothing(output_filepath)
        CSV.write(joinpath(output_filepath, "electricity_bill_results.csv"), bill_results)
    end

    # Return the electricity bill results
    return bill_results
end
