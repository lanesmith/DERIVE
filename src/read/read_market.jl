"""
    read_market(filepath::String)::Market

Load market prices and parameters from .csv files and return them in a Market struct.
"""
function read_market(filepath::String)::Market
    # Initialize market struct
    market = Dict{String,Any}(
        "iso_name" => nothing,
        "reg_up_enabled" => false,
        "reg_up_prices" => nothing,
        "reg_dn_enabled" => false,
        "reg_dn_prices" => nothing,
        "sp_res_enabled" => false,
        "sp_res_prices" => nothing,
        "ns_res_enabled" => false,
        "ns_res_prices" => nothing,
    )

    # Try loading the market parameters
    try
        market_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "market_parameters.csv"); transpose=true),
        )
        println("...loading market parameters")

        # Try assigning the different incentives parameters from the file
        for k in deleteat!(
            collect(keys(market)),
            findall(
                x -> x in
                ("reg_up_prices", "reg_dn_prices", "sp_res_prices", "ns_res_prices"),
                collect(keys(market)),
            ),
        )
            if !ismissing(market_parameters[1, k])
                market[k] = market_parameters[1, k]
            else
                println(
                    "The " *
                    k *
                    " parameter is not defined. Will default to " *
                    string(market[k]) *
                    ".",
                )
            end
        end
    catch e
        println(
            "Market parameters not found in " *
            filepath *
            ". Market parameters will default to not allowing incentives to be " *
            "considered.",
        )
    end

    # Try loading the market price profiles if they are enabled
    for market_product in ["reg_up", "reg_dn", "sp_res", "ns_res"]
        if market[market_product * "_enabled"]
            try
                market[market_product * "_prices"] = DataFrames.DataFrame(
                    CSV.File(joinpath(filepath, market_product * "_price_profile.csv")),
                )
                println("...loading " * market_product * " prices")
            catch e
                println(
                    "The " *
                    market_product *
                    " prices are not found in " *
                    filepath *
                    ". The parameters related to the " *
                    market_product *
                    " market will default to not allowing it to be considered.",
                )
                market[market_product * "_enabled"] = false
            end
        end
    end

    # Convert Dict to NamedTuple
    market = (; (Symbol(k) => v for (k, v) in market)...)

    # Convert NamedTuple to Market object
    market = Market(; market...)

    return market
end
