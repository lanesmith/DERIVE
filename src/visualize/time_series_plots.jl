"""
    plot_time_series_data(
        scenario::Scenario,
        tariff::Tariff,
        storage::Storage,
        results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame},
        start_date::String,
        end_date::Union{String,Nothing}=nothing;
        plot_demand::Bool=false,
        plot_net_demand::Bool=false,
        plot_net_exports::Bool=false,
        plot_pv_generation_btm::Bool=false,
        plot_pv_generation_export::Bool=false,
        plot_pv_generation_all::Bool=false,
        plot_bes_state_of_charge::Bool=false,
        plot_bes_charging::Bool=false,
        plot_bes_discharging_btm::Bool=false,
        plot_bes_discharging_export::Bool=false,
        plot_bes_discharging_all::Bool=false,
        plot_ssd_up_deviations::Bool=false,
        plot_ssd_down_deviations::Bool=false,
        plot_demand_shed::Bool=false,
        plot_energy_prices::Bool=false,
        plot_export_prices::Bool=false,
        show_tou_periods::Bool=false,
        legend_location::Union{Symbol,Nothing}=nothing,
    )

Plots the time-series results produced from a simulation run. Allows the user to specify 
which results they want to visualize.
"""
function plot_time_series_data(
    scenario::Scenario,
    tariff::Tariff,
    storage::Storage,
    results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame},
    start_date::String,
    end_date::Union{String,Nothing}=nothing;
    plot_demand::Bool=false,
    plot_net_demand::Bool=false,
    plot_net_exports::Bool=false,
    plot_pv_generation_btm::Bool=false,
    plot_pv_generation_export::Bool=false,
    plot_pv_generation_all::Bool=false,
    plot_bes_state_of_charge::Bool=false,
    plot_bes_charging::Bool=false,
    plot_bes_discharging_btm::Bool=false,
    plot_bes_discharging_export::Bool=false,
    plot_bes_discharging_all::Bool=false,
    plot_ssd_up_deviations::Bool=false,
    plot_ssd_down_deviations::Bool=false,
    plot_demand_shed::Bool=false,
    plot_energy_prices::Bool=false,
    plot_export_prices::Bool=false,
    show_tou_periods::Bool=false,
    legend_location::Union{Symbol,Nothing}=nothing,
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
    if plot_net_exports & !("net_exports" in names(results))
        throw(
            ErrorException(
                "Net exports data is not included in the provided results data set. " *
                "Please try again.",
            ),
        )
    end
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
    if plot_bes_state_of_charge & !("bes_state_of_charge" in names(results))
        throw(
            ErrorException(
                "BES state of charge data is not included in the provided results data " *
                "set. Please try again.",
            ),
        )
    end
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
    if plot_ssd_up_deviations & !("ssd_up_deviations" in names(results))
        throw(
            ErrorException(
                "Flexible demand upward deviation data is not included in the provided " *
                "results data set. Please try again.",
            ),
        )
    end
    if plot_ssd_down_deviations & !("ssd_down_deviations" in names(results))
        throw(
            ErrorException(
                "Flexible demand downward deviation data is not included in the provided " *
                "results data set. Please try again.",
            ),
        )
    end
    if plot_demand_shed & !("demand_shed" in names(results))
        throw(
            ErrorException(
                "Sheddable demand curtailment data is not included in the provided " *
                "results data set. Please try again.",
            ),
        )
    end
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

    # Determine the day number of the start date according to the inputs
    if occursin("-", start_date)
        start_day = Dates.dayofyear(
            Dates.Date(
                scenario.year,
                parse(Int64, split(start_date, "-")[1]),
                parse(Int64, split(start_date, "-")[2]),
            ),
        )
    elseif occursin("/", start_date)
        start_day = Dates.dayofyear(
            Dates.Date(
                scenario.year,
                parse(Int64, split(start_date, "/")[1]),
                parse(Int64, split(start_date, "/")[2]),
            ),
        )
    else
        throw(
            ErrorException(
                "An incorrect date format was provided for the start date. Dates must be " *
                "provided in mm-dd or mm/dd format. Please try again.",
            ),
        )
    end

    # Determine the day number of the end date, if applicable, according to the inputs
    if isnothing(end_date)
        end_day = start_day
    else
        if occursin("-", end_date)
            end_day = Dates.dayofyear(
                Dates.Date(
                    scenario.year,
                    parse(Int64, split(end_date, "-")[1]),
                    parse(Int64, split(end_date, "-")[2]),
                ),
            )
        elseif occursin("/", end_date)
            end_day = Dates.dayofyear(
                Dates.Date(
                    scenario.year,
                    parse(Int64, split(end_date, "/")[1]),
                    parse(Int64, split(end_date, "/")[2]),
                ),
            )
        else
            throw(
                ErrorException(
                    "An incorrect date format was provided for the end date. Dates must " *
                    "be provided in mm-dd or mm/dd format. Please try again.",
                ),
            )
        end
    end

    # Determine the first and last time step
    first_time_step = 24 * (start_day - 1) + 1
    last_time_step = 24 * end_day

    # Determine the plot types being considered
    power_plot = false
    soc_plot = false
    price_plot = false
    if plot_demand |
       plot_net_demand |
       plot_net_exports |
       plot_pv_generation_btm |
       plot_pv_generation_export |
       plot_pv_generation_all |
       plot_bes_charging |
       plot_bes_discharging_btm |
       plot_bes_discharging_export |
       plot_bes_discharging_all |
       plot_ssd_up_deviations |
       plot_ssd_down_deviations |
       plot_demand_shed
        power_plot = true
    end
    if plot_bes_state_of_charge
        soc_plot = true
    end
    if plot_energy_prices | plot_export_prices
        price_plot = true
    end
    if power_plot & soc_plot & price_plot
        throw(
            ErrorException(
                "Only two of the plot types (i.e., power, state of charge, and prices) " *
                "can be considered at the same time. Please try again.",
            ),
        )
    end

    # Create the relevant plots
    if isnothing(legend_location)
        fig = Plots.plot()
    else
        fig = Plots.plot(legend=legend_location)
    end
    if power_plot
        create_power_plot!(
            results,
            first_time_step,
            last_time_step,
            plot_demand,
            plot_net_demand,
            plot_net_exports,
            plot_pv_generation_btm,
            plot_pv_generation_export,
            plot_pv_generation_all,
            plot_bes_charging,
            plot_bes_discharging_btm,
            plot_bes_discharging_export,
            plot_bes_discharging_all,
            plot_ssd_up_deviations,
            plot_ssd_down_deviations,
            plot_demand_shed,
        )
        if soc_plot
            create_soc_plot!(
                results,
                storage,
                first_time_step,
                last_time_step,
                plot_bes_state_of_charge;
                second_plot=true,
            )
        elseif price_plot
            create_price_plot!(
                results,
                first_time_step,
                last_time_step,
                plot_energy_prices,
                plot_export_prices;
                second_plot=true,
            )
        end
    elseif price_plot
        create_price_plot!(
            results,
            first_time_step,
            last_time_step,
            plot_energy_prices,
            plot_export_prices,
        )
        if soc_plot
            create_soc_plot!(
                results,
                storage,
                first_time_step,
                last_time_step,
                plot_bes_state_of_charge;
                second_plot=true,
            )
        end
    elseif soc_plot
        create_soc_plot!(
            results,
            storage,
            first_time_step,
            last_time_step,
            plot_bes_state_of_charge,
        )
    end
    if show_tou_periods
        # Determine the start date
        if occursin("-", start_date)
            start_date_ = Dates.Date(
                scenario.year,
                parse(Int64, split(start_date, "-")[1]),
                parse(Int64, split(start_date, "-")[2]),
            )
        elseif occursin("/", start_date)
            start_date_ = Dates.Date(
                scenario.year,
                parse(Int64, split(start_date, "/")[1]),
                parse(Int64, split(start_date, "/")[2]),
            )
        end

        # Determine the end date
        if isnothing(end_date)
            end_date_ = start_date_
        else
            if occursin("-", end_date)
                end_date_ = Dates.Date(
                    scenario.year,
                    parse(Int64, split(end_date, "-")[1]),
                    parse(Int64, split(end_date, "-")[2]),
                )
            elseif occursin("/", end_date)
                end_date_ = Dates.Date(
                    scenario.year,
                    parse(Int64, split(end_date, "/")[1]),
                    parse(Int64, split(end_date, "/")[2]),
                )
            end
        end

        # Determine the season in which the selected days occur
        seasons_by_month = Dict{Int64,String}(
            v => k for k in keys(tariff.months_by_season) for
            v in values(tariff.months_by_season[k])
        )
        seasons_list = Vector{String}()
        for d = start_date_:Dates.Day(1):end_date_
            push!(seasons_list, seasons_by_month[Dates.month(d)])
        end

        # Find the first and last hours of the peak period
        seasons_peak_dict = Dict{String,Dict}()
        for s in unique(seasons_list)
            # Find every peak-period hour for the season
            peak_hours = Vector{Int64}()
            for h in keys(tariff.energy_tou_rates[s])
                if tariff.energy_tou_rates[s][h]["label"] == "peak"
                    push!(peak_hours, h)
                end
            end
            sort!(peak_hours)

            # Determine the first and last hours of the peak period
            seasons_peak_dict[s] = Dict{String,Vector{Int64}}()
            seasons_peak_dict[s]["first_peak_hour"] = Vector{Int64}()
            seasons_peak_dict[s]["last_peak_hour"] = Vector{Int64}()
            for n in eachindex(peak_hours)
                # Account for the first hour
                if n == 1
                    push!(seasons_peak_dict[s]["first_peak_hour"], peak_hours[n])
                end

                # Check if the peak period is continuous
                if n > 1
                    if peak_hours[n] - peak_hours[n - 1] > 1
                        push!(seasons_peak_dict[s]["last_peak_hour"], peak_hours[n - 1])
                        push!(seasons_peak_dict[s]["first_peak_hour"], peak_hours[n])
                    end
                end

                # Account for the last hour
                if n == lastindex(peak_hours)
                    push!(seasons_peak_dict[s]["last_peak_hour"], peak_hours[n])
                end
            end
        end

        # Plot the peak periods
        day_num = 0
        for d in seasons_list
            for p in eachindex(seasons_peak_dict[d]["first_peak_hour"])
                Plots.vspan!(
                    [
                        24 * day_num + seasons_peak_dict[d]["first_peak_hour"][p],
                        24 * day_num + seasons_peak_dict[d]["last_peak_hour"][p],
                    ],
                    color=:yellow,
                    fill=:yellow,
                    alpha=0.15,
                    label=false,
                )
            end
            day_num += 1
        end
    end

    # Show the plot
    Plots.display(fig)
end

"""
    create_power_plot!(
        results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame},
        first_time_step::Int64,
        last_time_step::Int64,
        plot_demand::Bool,
        plot_net_demand::Bool,
        plot_net_exports::Bool,
        plot_pv_generation_btm::Bool,
        plot_pv_generation_export::Bool,
        plot_pv_generation_all::Bool,
        plot_bes_charging::Bool,
        plot_bes_discharging_btm::Bool,
        plot_bes_discharging_export::Bool,
        plot_bes_discharging_all::Bool,
        plot_ssd_up_deviations::Bool,
        plot_ssd_down_deviations::Bool,
        plot_demand_shed::Bool,
    )

Creates the plot for the power-related time-series results.
"""
function create_power_plot!(
    results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame},
    first_time_step::Int64,
    last_time_step::Int64,
    plot_demand::Bool,
    plot_net_demand::Bool,
    plot_net_exports::Bool,
    plot_pv_generation_btm::Bool,
    plot_pv_generation_export::Bool,
    plot_pv_generation_all::Bool,
    plot_bes_charging::Bool,
    plot_bes_discharging_btm::Bool,
    plot_bes_discharging_export::Bool,
    plot_bes_discharging_all::Bool,
    plot_ssd_up_deviations::Bool,
    plot_ssd_down_deviations::Bool,
    plot_demand_shed::Bool,
)
    # Plot demand, if applicable
    if plot_demand
        Plots.plot!(
            results[first_time_step:last_time_step, :demand];
            label="demand",
            color=:black,
            linestyle=:solid,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot net demand, if applicable
    if plot_net_demand
        Plots.plot!(
            results[first_time_step:last_time_step, :net_demand];
            label="net_demand",
            color=:black,
            linestyle=:dash,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot net exports, if applicable
    if plot_net_exports
        Plots.plot!(
            results[first_time_step:last_time_step, :net_exports];
            label="net_exports",
            color=:gray76,
            linestyle=:solid,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot PV generation for meeting behind-the-meter demand, if applicable
    if plot_pv_generation_btm
        Plots.plot!(
            results[first_time_step:last_time_step, :pv_generation_btm];
            label="pv_generation_btm",
            color=:darkorange,
            linestyle=(
                !plot_pv_generation_export & !plot_pv_generation_all ? :solid : :dash
            ),
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot PV generation for providing exports, if applicable
    if plot_pv_generation_export
        Plots.plot!(
            results[first_time_step:last_time_step, :pv_generation_export];
            label="pv_generation_export",
            color=:darkorange,
            linestyle=(
                !plot_pv_generation_btm & !plot_pv_generation_all ? :solid : :dashdotdot
            ),
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot all PV generation that is used, if applicable
    if plot_pv_generation_all
        Plots.plot!(
            results[first_time_step:last_time_step, :pv_generation_all];
            label="pv_generation_all",
            color=:darkorange,
            linestyle=:solid,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot BES charging, if applicable
    if plot_bes_charging
        Plots.plot!(
            results[first_time_step:last_time_step, :bes_charging];
            label="bes_charging",
            color=:blue,
            linestyle=:solid,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot BES discharging for meeting behind-the-meter demand, if applicable
    if plot_bes_discharging_btm
        Plots.plot!(
            results[first_time_step:last_time_step, :bes_discharging_btm];
            label="bes_discharging_btm",
            color=:cornflowerblue,
            linestyle=(
                !plot_bes_discharging_export & !plot_bes_discharging_all ? :solid : :dash
            ),
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot BES discharging for providing exports, if applicable
    if plot_bes_discharging_export
        Plots.plot!(
            results[first_time_step:last_time_step, :bes_discharging_export];
            label="bes_discharging_export",
            color=:cornflowerblue,
            linestyle=(
                !plot_bes_discharging_btm & !plot_bes_discharging_all ? :solid :
                :dashdotdot
            ),
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot all BES discharging, if applicable
    if plot_bes_discharging_all
        Plots.plot!(
            results[first_time_step:last_time_step, :bes_discharging_all];
            label="bes_discharging_all",
            color=:cornflowerblue,
            linestyle=:solid,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot upward shiftable demand deviations, if applicable
    if plot_ssd_up_deviations
        Plots.plot!(
            results[first_time_step:last_time_step, :ssd_deviations_up];
            label="ssd_deviations_up",
            color=:purple1,
            linestyle=:solid,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot downward shiftable demand deviations, if applicable
    if plot_ssd_down_deviations
        Plots.plot!(
            results[first_time_step:last_time_step, :ssd_deviations_down];
            label="ssd_deviations_down",
            color=:magenta,
            linestyle=:solid,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end

    # Plot curtailed sheddable demand, if applicable
    if plot_demand_shed
        Plots.plot!(
            results[first_time_step:last_time_step, :demand_shed];
            label="demand_shed",
            color=:saddlebrown,
            linestyle=:solid,
            xlims=[0, Inf],
            ylims=[0, Inf],
            xlabel="Time Step",
            ylabel="Power (kW)",
        )
    end
end

"""
    create_soc_plot!(
        results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame},
        storage::Storage,
        first_time_step::Int64,
        last_time_step::Int64,
        plot_bes_state_of_charge::Bool;
        second_plot::Bool=false,
    )

Creates the plot for the battery energy storage (BES) state of charge results.
"""
function create_soc_plot!(
    results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame},
    storage::Storage,
    first_time_step::Int64,
    last_time_step::Int64,
    plot_bes_state_of_charge::Bool;
    second_plot::Bool=false,
)
    # Plot BES state of charge, if applicable
    if plot_bes_state_of_charge
        if second_plot
            Plots.plot!(
                twinx(),
                (
                    results[first_time_step:last_time_step, :bes_state_of_charge] ./
                    (storage.power_capacity * storage.duration) .* 100
                );
                label=false,
                color=:mediumseagreen,
                linestyle=:dash,
                xlims=[0, Inf],
                ylims=[0, Inf],
                ylabel="BES State of Charge (%)",
            )
            Plots.plot!(
                [-1],
                [0];
                label="bes_state_of_charge",
                color=:mediumseagreen,
                linestyle=:dash,
                xlims=[0, Inf],
                ylims=[0, Inf],
            )
        else
            Plots.plot!(
                (
                    results[first_time_step:last_time_step, :bes_state_of_charge] ./
                    (storage.power_capacity * storage.duration) .* 100
                );
                label="bes_state_of_charge",
                color=:mediumseagreen,
                linestyle=:dash,
                xlims=[0, Inf],
                ylims=[0, Inf],
                xlabel="Time Step",
                ylabel="BES State of Charge (%)",
            )
        end
    end
end

"""
    create_price_plot!(
        results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame},
        first_time_step::Int64,
        last_time_step::Int64,
        plot_energy_prices::Bool,
        plot_export_prices::Bool;
        second_plot::Bool=false,
    )

Creates the plot for the price-related time-series results.
"""
function create_price_plot!(
    results::Union{Dict{String,Union{DataFrames.DataFrame,Dict}},DataFrames.DataFrame},
    first_time_step::Int64,
    last_time_step::Int64,
    plot_energy_prices::Bool,
    plot_export_prices::Bool;
    second_plot::Bool=false,
)
    # Plot energy prices, if applicable
    if plot_energy_prices
        if second_plot
            Plots.plot!(
                twinx(),
                results[first_time_step:last_time_step, :energy_prices];
                label=false,
                color=:red,
                linestyle=:dot,
                xlims=[0, Inf],
                ylims=[0, Inf],
                ylabel="Price (\$)",
            )
            Plots.plot!(
                [-1],
                [0];
                label="energy_prices",
                color=:red,
                linestyle=:dot,
                xlims=[0, Inf],
                ylims=[0, Inf],
            )
        else
            Plots.plot!(
                results[first_time_step:last_time_step, :energy_prices];
                label="energy_prices",
                color=:red,
                linestyle=:dot,
                xlims=[0, Inf],
                ylims=[0, Inf],
                xlabel="Time Step",
                ylabel="Price (\$)",
            )
        end
    end

    # Plot export prices, if applicable
    if plot_export_prices
        if second_plot
            Plots.plot!(
                twinx(),
                results[first_time_step:last_time_step, :export_prices];
                label=false,
                color=:salmon,
                linestyle=:dot,
                xlims=[0, Inf],
                ylims=[0, Inf],
                ylabel="Price (\$)",
            )
            Plots.plot!(
                [-1],
                [0];
                label="export_prices",
                color=:salmon,
                linestyle=:dot,
                xlims=[0, Inf],
                ylims=[0, Inf],
            )
        else
            Plots.plot!(
                results[first_time_step:last_time_step, :export_prices];
                label="export_prices",
                color=:salmon,
                linestyle=:dot,
                xlims=[0, Inf],
                ylims=[0, Inf],
                xlabel="Time Step",
                ylabel="Price (\$)",
            )
        end
    end
end
