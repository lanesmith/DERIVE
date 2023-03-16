module DERIVE

using CSV
using DataFrames
using Dates
using Gurobi
using JuMP
using TOML

# Inlcude the ability to read input data
include("read/types.jl")
include("read/read_scenario.jl")
include("read/read_tariff.jl")
include("read/read_market.jl")
include("read/read_incentives.jl")
include("read/read_demand.jl")
include("read/read_solar.jl")
include("read/read_storage.jl")

# Include the ability to prepare input data
include("prepare/prepare_prices.jl")
include("prepare/prepare_solar.jl")

# Include the mathematical models
include("model/model.jl")
include("model/base/demand.jl")
include("model/assets/solar_photovoltaics.jl")
include("model/assets/battery_energy_storage.jl")
include("model/assets/simple_shiftable_demand.jl")
include("model/tariffs/interconnection_rules.jl")

# Include the simulation architecture
include("simulate/simulate.jl")
include("simulate/simulate_by_day.jl")
include("simulate/simulate_by_month.jl")
include("simulate/simulate_by_year.jl")

# Include the ability to visualize data
include("visualize/header.jl")

end
