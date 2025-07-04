module DERIVE

using CSV
using DataFrames
using Dates
using Gurobi
using JuMP
using Plots
using Statistics
using TOML

# Inlcude the ability to read input data
include("input/types.jl")
include("input/read_scenario.jl")
include("input/read_tariff.jl")
include("input/read_market.jl")
include("input/read_incentives.jl")
include("input/read_demand.jl")
include("input/read_solar.jl")
include("input/read_storage.jl")
include("input/read_optimizer_attributes.jl")

# Include the ability to prepare input data
include("preprocess/prepare_demand.jl")
include("preprocess/prepare_prices.jl")
include("preprocess/prepare_solar.jl")

# Include the mathematical models
include("model/model.jl")
include("model/base/demand.jl")
include("model/assets/solar_photovoltaics.jl")
include("model/assets/battery_energy_storage.jl")
include("model/assets/simple_shiftable_demand.jl")
include("model/assets/sheddable_demand.jl")
include("model/mechanisms/time_of_use_rates.jl")
include("model/mechanisms/net_energy_metering.jl")
include("model/mechanisms/tiered_energy_rates.jl")
include("model/mechanisms/investment_tax_credits.jl")
include("model/mechanisms/tariff_interconnection_rules.jl")

# Include the simulation architecture
include("simulate/simulate.jl")
include("simulate/tools/create_sets.jl")
include("simulate/tools/sensitivity_analysis.jl")
include("simulate/optimization_horizons/simulate_by_day.jl")
include("simulate/optimization_horizons/simulate_by_month.jl")
include("simulate/optimization_horizons/simulate_by_year.jl")

# Include the ability to access and postprocess the results
include("postprocess/time_series_results.jl")
include("postprocess/investment_cost_results.jl")
include("postprocess/electricity_bill_results.jl")
include("postprocess/tiered_energy_results.jl")

# Include the ability to visualize data and other information
include("visualize/header.jl")
include("visualize/time_series_plots.jl")
include("visualize/time_series_heatmaps.jl")

end
