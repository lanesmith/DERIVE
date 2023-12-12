"""
    initialize_time_series_results(
        tariff::Tariff,
        solar::Solar,
        storage::Storage,
    )::DataFrames.DataFrame

Initialize the DataFrame of time-series results used in the simulation. Included columns 
are based on participating technologies and mechanisms.
"""
function initialize_time_series_results(
    tariff::Tariff,
    demand::Demand,
    solar::Solar,
    storage::Storage,
)::DataFrames.DataFrame
    # Initialize the DataFrame of time-series results
    time_series_results = DataFrames.DataFrame(
        timestamp=Dates.DateTime[],
        demand=Float64[],
        net_demand=Float64[],
    )

    # Add columns to time_series_results if net energy metering (NEM) is enabled
    if tariff.nem_enabled & solar.enabled
        time_series_results[!, :net_exports] = Float64[]
    end

    # Add columns to time_series_results if solar photovoltaics (PVs) are enabled
    if solar.enabled
        time_series_results[!, :pv_generation_btm] = Float64[]
        if tariff.nem_enabled & !solar.nonexport
            time_series_results[!, :pv_generation_export] = Float64[]
        end
    end

    # Add columns to time_series_results if battery energy storage (BES) is enabled
    if storage.enabled
        time_series_results[!, :bes_state_of_charge] = Float64[]
        time_series_results[!, :bes_charging] = Float64[]
        time_series_results[!, :bes_discharging_btm] = Float64[]
        if tariff.nem_enabled & solar.enabled & !storage.nonexport
            time_series_results[!, :bes_discharging_export] = Float64[]
        end
    end

    # Add columns to time_series_results if simple shiftable demand (SSD) is enabled
    if demand.simple_shift_enabled
        time_series_results[!, :ssd_up_deviations] = Float64[]
        time_series_results[!, :ssd_down_deviations] = Float64[]
    end

    # Add columns to time_series_results for price information
    time_series_results[!, :energy_prices] = Float64[]
    if tariff.nem_enabled & solar.enabled
        time_series_results[!, :export_prices] = Float64[]
    end

    # Return the time-series results
    return time_series_results
end

"""
    store_time_series_results!(
        m::JuMP.Model,
        scenario::Scenario,
        sets::Sets,
        time_series_results::DataFrames.DateFrame,
        start_date::Dates.Date,
        end_date::Dates.Date,
    )

Store and update the DataFrame of time-series results used in the simulation. Include 
values from the JuMP optimization model and the Sets object based on the preexisting column 
names present in the provided DataFrame.
"""
function store_time_series_results!(
    m::JuMP.Model,
    scenario::Scenario,
    sets::Sets,
    time_series_results::DataFrames.DataFrame,
    start_date::Dates.Date,
    end_date::Dates.Date,
)
    # Create a temporary DataFrame to store information from this iteration
    temp_results = DataFrames.DataFrame()
    for c in names(time_series_results)
        if c == "timestamp"
            temp_results[!, c] = collect(
                Dates.DateTime(
                    Dates.year(start_date),
                    Dates.month(start_date),
                    Dates.day(start_date),
                    0,
                    0,
                ):Dates.Minute(scenario.interval_length):Dates.DateTime(
                    Dates.year(end_date),
                    Dates.month(end_date),
                    Dates.day(end_date),
                    23,
                    45,
                ),
            )
        elseif c == "demand"
            temp_results[!, c] = sets.demand
        elseif c == "net_demand"
            temp_results[!, c] = JuMP.value.(m[:d_net])
        elseif c == "net_exports"
            temp_results[!, c] = JuMP.value.(m[:p_exports])
        elseif c == "pv_generation_btm"
            temp_results[!, c] = JuMP.value.(m[:p_pv_btm])
        elseif c == "pv_generation_export"
            temp_results[!, c] = JuMP.value.(m[:p_pv_exp])
        elseif c == "bes_state_of_charge"
            temp_results[!, c] = JuMP.value.(m[:soc])
        elseif c == "bes_charging"
            temp_results[!, c] = JuMP.value.(m[:p_cha])
        elseif c == "bes_discharging_btm"
            temp_results[!, c] = JuMP.value.(m[:p_dis_btm])
        elseif c == "bes_discharging_export"
            temp_results[!, c] = JuMP.value.(m[:p_dis_exp])
        elseif c == "ssd_up_deviations"
            temp_results[!, c] = JuMP.value.(m[:d_dev_up])
        elseif c == "ssd_down_deviations"
            temp_results[!, c] = JuMP.value.(m[:d_dev_dn])
        elseif c == "energy_prices"
            temp_results[!, c] = sets.energy_prices
        elseif c == "export_prices"
            temp_results[!, c] = sets.nem_prices
        else
            throw(
                ErrorException(
                    c *
                    " is not a recognized column name in the DataFrame of time-series " *
                    "results. Please try again.",
                ),
            )
        end
    end

    # Append the temporary DataFrame to the DataFrame of time-series results
    append!(time_series_results, temp_results)
end
