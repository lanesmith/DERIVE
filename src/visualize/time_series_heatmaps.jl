"""
    plot_solar_heatmap(
        scenario::Scenario,
        results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame};
        plot_pv_generation_btm::Bool=false,
        plot_pv_generation_export::Bool=false,
        plot_pv_generation_all::Bool=false,
        heatmap_color::Union{Symbol,Nothing}=nothing,
    )

Plots an annual time-series solar PV result on a time-series heatmap.
"""
function plot_solar_heatmap(
    scenario::Scenario,
    results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame};
    plot_pv_generation_btm::Bool=false,
    plot_pv_generation_export::Bool=false,
    plot_pv_generation_all::Bool=false,
    heatmap_color::Union{Symbol,Nothing}=nothing,
)
    # Check the input's data type and throw errors if needed
    if typeof(results) == Dict{Union{DataFrames.DataFrame,Dict}}
        try
            results = results["time-series"]
        catch e
            throw(
                ErrorException(
                    "Time-series data is not included in the provided results. Please " *
                    "try again.",
                ),
            )
        end
    elseif typeof(results) != DataFrames.DataFrame
        throw(
            ErrorException(
                "The provided results do not contain time-series data in the expected " *
                "format. Please try again.",
            ),
        )
    end

    # Check the provided inputs to make sure only one result is plotted
    if !(
        (plot_pv_generation_btm & !plot_pv_generation_export & !plot_pv_generation_all) |
        (!plot_pv_generation_btm & plot_pv_generation_export & !plot_pv_generation_all) |
        (!plot_pv_generation_btm & !plot_pv_generation_export & plot_pv_generation_all)
    )
        throw(
            ErrorException(
                "Only one time-series solar PV result can be plotted on the heatmap at a " *
                "time. Please try again.",
            ),
        )
    end

    # Check the provided inputs to see if they are in the results
    if plot_pv_generation_btm & !("pv_generation_btm" in names(results))
        throw(
            ErrorException(
                "PV generation for meeting behind-the-meter demand data is not included " *
                "in the provided results data set. Please try again.",
            ),
        )
    end
    if plot_pv_generation_export & !("pv_generation_export" in names(results))
        throw(
            ErrorException(
                "PV generation for providing exports data is not included in the " *
                "provided results data set. Please try again.",
            ),
        )
    end
    if plot_pv_generation_all &
       !("pv_generation_btm" in names(results)) &
       !("pv_generation_export" in names(results))
        throw(
            ErrorException(
                "PV generation for meeting behind-the-meter demand data and PV " *
                "generation for providing exports data is not included in the provided " *
                "results data set. Please try again.",
            ),
        )
    end

    # Create the heatmap components
    hours = Dates.Time(0, 0):Dates.Minute(scenario.interval_length):Dates.Time(23, 45)
    days = first(results[!, "timestamp"]):Dates.Day(1):last(results[!, "timestamp"])
    if plot_pv_generation_btm
        fig = Plots.heatmap(
            days,
            hours,
            reshape(results[!, "pv_generation_btm"], (length(hours), length(days)));
            xlabel="Days",
            ylabel="Hours",
            colorbar_title="PV Generation (kW)",
            color=isnothing(heatmap_color) ? :inferno : heatmap_color,
        )
    elseif plot_pv_generation_export
        fig = Plots.heatmap(
            days,
            hours,
            reshape(results[!, "pv_generation_export"], (length(hours), length(days)));
            xlabel="Days",
            ylabel="Hours",
            colorbar_title="PV Generation (kW)",
            color=isnothing(heatmap_color) ? :inferno : heatmap_color,
        )
    elseif plot_pv_generation_all
        fig = Plots.heatmap(
            days,
            hours,
            reshape(
                (results[!, "pv_generation_btm"] .+ results[!, "pv_generation_export"]),
                (length(hours), length(days)),
            );
            xlabel="Days",
            ylabel="Hours",
            colorbar_title="PV Generation (kW)",
            color=isnothing(heatmap_color) ? :inferno : heatmap_color,
        )
    end

    # Show the plot
    Plots.display(fig)
end

"""
    plot_storage_heatmap(
        scenario::Scenario,
        results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame};
        plot_bes_charging::Bool=false,
        plot_bes_discharging_btm::Bool=false,
        plot_bes_discharging_export::Bool=false,
        plot_bes_discharging_all::Bool=false,
    )

Plots annual time-series BES charging and discharging results on a time-series heatmap.
"""
function plot_storage_heatmap(
    scenario::Scenario,
    results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame};
    plot_bes_charging::Bool=false,
    plot_bes_discharging_btm::Bool=false,
    plot_bes_discharging_export::Bool=false,
    plot_bes_discharging_all::Bool=false,
    heatmap_color::Union{Symbol,Nothing}=nothing,
)
    # Check the input's data type and throw errors if needed
    if typeof(results) == Dict{Union{DataFrames.DataFrame,Dict}}
        try
            results = results["time-series"]
        catch e
            throw(
                ErrorException(
                    "Time-series data is not included in the provided results. Please " *
                    "try again.",
                ),
            )
        end
    elseif typeof(results) != DataFrames.DataFrame
        throw(
            ErrorException(
                "The provided results do not contain time-series data in the expected " *
                "format. Please try again.",
            ),
        )
    end

    # Check the provided discharging-related inputs to make sure only one result is plotted
    if !(
        (
            plot_bes_discharging_btm &
            !plot_bes_discharging_export &
            !plot_bes_discharging_all
        ) |
        (
            !plot_bes_discharging_btm &
            plot_bes_discharging_export &
            !plot_bes_discharging_all
        ) |
        (
            !plot_bes_discharging_btm &
            !plot_bes_discharging_export &
            plot_bes_discharging_all
        )
    )
        throw(
            ErrorException(
                "Only one BES discharging time-series result can be plotted on the " *
                "heatmap at a time. Please try again.",
            ),
        )
    end

    # Check the input's data type and throw errors if needed
    if plot_bes_charging & !("bes_charging" in names(results))
        throw(
            ErrorException(
                "BES charging data is not included in the provided results data set. " *
                "Please try again.",
            ),
        )
    end
    if plot_bes_discharging_btm & !("bes_discharging_btm" in names(results))
        throw(
            ErrorException(
                "BES discharging for meeting behind-the-meter demand data is not included " *
                "in the provided results data set. Please try again.",
            ),
        )
    end
    if plot_bes_discharging_export & !("bes_discharging_export" in names(results))
        throw(
            ErrorException(
                "BES discharging for providing exports data is not included in the " *
                "provided results data set. Please try again.",
            ),
        )
    end
    if plot_bes_discharging_all &
       !("bes_discharging_btm" in names(results)) &
       !("bes_discharging_export" in names(results))
        throw(
            ErrorException(
                "BES discharging for meeting behind-the-meter demand data and BES " *
                "discharging for providing exports data is not included in the provided " *
                "results data set. Please try again.",
            ),
        )
    end

    # Create the heatmap components
    hours = Dates.Time(0, 0):Dates.Minute(scenario.interval_length):Dates.Time(23, 45)
    days = first(results[!, "timestamp"]):Dates.Day(1):last(results[!, "timestamp"])
    if plot_bes_discharging_btm
        values = results[!, "bes_discharging_btm"]
        color = isnothing(heatmap_color) ? :inferno : heatmap_color
    elseif plot_bes_discharging_export
        values = results[!, "bes_discharging_export"]
        color = isnothing(heatmap_color) ? :inferno : heatmap_color
    elseif plot_bes_discharging_all
        values = results[!, "bes_discharging_btm"] .+ results[!, "bes_discharging_export"]
        color = isnothing(heatmap_color) ? :inferno : heatmap_color
    end
    if plot_bes_charging
        if plot_bes_discharging_btm | plot_bes_discharging_export | plot_bes_discharging_all
            values .-= results[!, "bes_charging"]
            color = isnothing(heatmap_color) ? :vik : heatmap_color
        else
            values = results[!, "bes_charging"]
            color = isnothing(heatmap_color) ? :inferno : heatmap_color
        end
    end
    fig = Plots.heatmap(
        days,
        hours,
        reshape(values, (length(hours), length(days)));
        xlabel="Days",
        ylabel="Hours",
        colorbar_title="Net BES Discharging Power (kW)",
        color=color,
    )

    # Show the plot
    Plots.display(fig)
end

"""
    plot_price_heatmap(
        scenario::Scenario,
        results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame};
        plot_energy_prices::Bool=false,
        plot_export_prices::Bool=false,
    )

Plots an annual time-series price result on a time-series heatmap.
"""
function plot_price_heatmap(
    scenario::Scenario,
    results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame};
    plot_energy_prices::Bool=false,
    plot_export_prices::Bool=false,
    heatmap_color::Union{Symbol,Nothing}=nothing,
)
    # Check the input's data type and throw errors if needed
    if typeof(results) == Dict{Union{DataFrames.DataFrame,Dict}}
        try
            results = results["time-series"]
        catch e
            throw(
                ErrorException(
                    "Time-series data is not included in the provided results. Please " *
                    "try again.",
                ),
            )
        end
    elseif typeof(results) != DataFrames.DataFrame
        throw(
            ErrorException(
                "The provided results do not contain time-series data in the expected " *
                "format. Please try again.",
            ),
        )
    end

    # Check the provided inputs to make sure only one result is plotted
    if !(plot_energy_prices ⊻ plot_export_prices)
        throw(
            ErrorException(
                "Only one time-series price result can be plotted on the heatmap at a " *
                "time. Please try again.",
            ),
        )
    end

    # Check the provided inputs to see if they are in the results
    if plot_energy_prices & !("energy_prices" in names(results))
        throw(
            ErrorException(
                "Energy price data is not included in the provided results data set." *
                "Please try again.",
            ),
        )
    end
    if plot_export_prices & !("export_prices" in names(results))
        throw(
            ErrorException(
                "Export price data is not included in the provided results data set." *
                "Please try again.",
            ),
        )
    end

    # Create the heatmap components
    hours = Dates.Time(0, 0):Dates.Minute(scenario.interval_length):Dates.Time(23, 45)
    days = first(results[!, "timestamp"]):Dates.Day(1):last(results[!, "timestamp"])
    if plot_energy_prices
        fig = Plots.heatmap(
            days,
            hours,
            reshape(results[!, "energy_prices"], (length(hours), length(days)));
            xlabel="Days",
            ylabel="Hours",
            colorbar_title="Energy Prices (\$/kWh)",
            color=isnothing(heatmap_color) ? :inferno : heatmap_color,
        )
    elseif plot_export_prices
        fig = Plots.heatmap(
            days,
            hours,
            reshape(results[!, "export_prices"], (length(hours), length(days)));
            xlabel="Days",
            ylabel="Hours",
            colorbar_title="Export Prices (\$/kWh)",
            color=isnothing(heatmap_color) ? :inferno : heatmap_color,
        )
    end

    # Show the plot
    Plots.display(fig)
end

"""
    plot_demand_heatmap(
        scenario::Scenario,
        results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame};
        plot_demand::Bool=false,
        plot_net_demand::Bool=false,
    )

Plots an annual time-series price result on a time-series heatmap.
"""
function plot_demand_heatmap(
    scenario::Scenario,
    results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame};
    plot_demand::Bool=false,
    plot_net_demand::Bool=false,
    heatmap_color::Union{Symbol,Nothing}=nothing,
)
    # Check the input's data type and throw errors if needed
    if typeof(results) == Dict{Union{DataFrames.DataFrame,Dict}}
        try
            results = results["time-series"]
        catch e
            throw(
                ErrorException(
                    "Time-series data is not included in the provided results. Please " *
                    "try again.",
                ),
            )
        end
    elseif typeof(results) != DataFrames.DataFrame
        throw(
            ErrorException(
                "The provided results do not contain time-series data in the expected " *
                "format. Please try again.",
            ),
        )
    end

    # Check the provided inputs to make sure only one result is plotted
    if !(plot_demand ⊻ plot_net_demand)
        throw(
            ErrorException(
                "Only one time-series demand result can be plotted on the heatmap at a " *
                "time. Please try again.",
            ),
        )
    end

    # Check the provided inputs to see if they are in the results
    if plot_demand & !("demand" in names(results))
        throw(
            ErrorException(
                "Demand data is not included in the provided results data set. Please " *
                "try again.",
            ),
        )
    end
    if plot_net_demand & !("net_demand" in names(results))
        throw(
            ErrorException(
                "Net demand data is not included in the provided results data set. " *
                "Please try again.",
            ),
        )
    end

    # Create the heatmap components
    hours = Dates.Time(0, 0):Dates.Minute(scenario.interval_length):Dates.Time(23, 45)
    days = first(results[!, "timestamp"]):Dates.Day(1):last(results[!, "timestamp"])
    if plot_demand
        fig = Plots.heatmap(
            days,
            hours,
            reshape(results[!, "demand"], (length(hours), length(days)));
            xlabel="Days",
            ylabel="Hours",
            colorbar_title="Demand (kW)",
            color=isnothing(heatmap_color) ? :inferno : heatmap_color,
        )
    elseif plot_net_demand
        fig = Plots.heatmap(
            days,
            hours,
            reshape(results[!, "net_demand"], (length(hours), length(days)));
            xlabel="Days",
            ylabel="Hours",
            colorbar_title="Net Demand (kW)",
            color=isnothing(heatmap_color) ? :inferno : heatmap_color,
        )
    end

    # Show the plot
    Plots.display(fig)
end
