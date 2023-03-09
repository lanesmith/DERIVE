"""
    read_scenario(filepath::String)::Scenario

Load scenario parameters from .csv file and return them in a Scenario struct.
"""
function read_scenario(filepath::String)::Scenario
    # Initialize scenario struct
    scenario = Dict{String,Any}(
        "problem_type" => "",
        "interval_length" => "hour",
        "optimization_horizon" => "month",
        "optimization_solver" => "Gurobi",
        "weather_data" => nothing,
        "latitude" => nothing,
        "longitude" => nothing,
        "timezone" => nothing,
        "payback_period" => nothing,
        "year" => 0,
    )

    # Try loading the scenario parameters
    println("...loading scenario parameters")
    try
        scenario_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "scenario_parameters.csv"); transpose=true),
        )

        # Try assigning the different scenario parameters from the file
        for k in intersect(keys(scenario), names(scenario_parameters))
            if !ismissing(scenario_parameters[1, k])
                scenario[k] = scenario_parameters[1, k]
            else
                if k in deleteat!(
                    collect(intersect(keys(scenario), names(scenario_parameters))),
                    findall(
                        x -> x in ("problem_type", "year"),
                        collect(intersect(keys(scenario), names(scenario_parameters))),
                    ),
                )
                    println(
                        "The " *
                        k *
                        " parameter is not defined. Will default to " *
                        string(scenario[k]) *
                        ".",
                    )
                else
                    throw(
                        ErrorException(
                            k * " not found in scenario_parameters.csv. Please try again.",
                        ),
                    )
                end
            end
        end
    catch e
        throw(
            ErrorException(
                "Scenario parameters not found in " * filepath * ". Please try again.",
            ),
        )
    end

    # Try to access the specified weather data
    try
        # Get the file name of the desired weather data
        weather_file_name =
            DataFrames.DataFrame(
                CSV.File(joinpath(filepath, "scenario_parameters.csv"); transpose=true),
            )[
                1,
                "weather_file_name",
            ] * ".csv"

        # Access the weather data from the specified location; silencewarnings set to true 
        # to avoid excessive missing data warnings
        weather_data = DataFrames.DataFrame(
            CSV.File(
                joinpath(filepath, "weather_data", weather_file_name);
                silencewarnings=true,
            ),
        )

        # Try to populate the latitiude and longitude data
        for k in ["latitude", "longitude"]
            if isnothing(scenario[k])
                try
                    scenario[k] = abs(parse(Float64, weather_data[1, titlecase(k)]))
                catch e
                    throw(
                        ErrorException(
                            "The " *
                            k *
                            " parameter is not provided in the weather data. Please try again.",
                        ),
                    )
                end
            elseif floor(abs(parse(Float64, weather_data[1, titlecase(k)])); digits=1) !=
                   floor(scenario[k]; digits=1)
                throw(
                    ErrorException(
                        "User-defined " *
                        k *
                        " does not match that listed in the weather data. Please try again.",
                    ),
                )
            end
        end

        # Create mapping between UTC offset and time zone name
        utc_offset_to_timezone = Dict{Int64,String}(
            -5 => "Eastern",
            -6 => "Central",
            -7 => "Mountain",
            -8 => "Pacific",
            -9 => "Alaskan",
            -10 => "Hawaiian",
        )

        # Try to populate the time zone data
        if isnothing(scenario["timezone"])
            try
                scenario["timezone"] =
                    utc_offset_to_timezone[parse(Int64, weather_data[1, "Time Zone"])]
            catch e
                throw(
                    ErrorException(
                        "The timezone parameter is not provided by the user and is not " *
                        "found in the weather data. Please try again",
                    ),
                )
            end
        elseif utc_offset_to_timezone[parse(Int64, weather_data[1, "Time Zone"])] !=
               scenario["timezone"]
            throw(
                ErrorException(
                    "User-defined time zone does not match that listed in the weather " *
                    "data. Please try again.",
                ),
            )
        end

        # Trim weather_data to only include the weather data; exclude location information
        weather_data = weather_data[2:end, all.(!ismissing, eachcol(weather_data))]
        weather_data = rename!(weather_data, Symbol.(Vector(weather_data[1, :])))[2:end, :]

        # Try to populate the weather data
        try
            # Initialize the DataFrame with time stamps
            scenario["weather_data"] = DataFrames.DataFrame(
                "timestamp" => collect(
                    Dates.DateTime(scenario["year"], 1, 1, 0):Dates.Hour(1):Dates.DateTime(
                        scenario["year"],
                        12,
                        31,
                        23,
                    ),
                ),
            )

            # Check that the user-defined year is as long as the provided weather data
            if length(scenario["weather_data"][!, "timestamp"]) !=
               length(weather_data[!, "DNI"])
                throw(
                    ErrorException(
                        "The user-defined year and weather data have a length mismatch. " *
                        "Please try again.",
                    ),
                )
            end

            # Add the weather data to the appropriate DataFrame
            insertcols!(
                scenario["weather_data"],
                "timestamp",
                "DNI" => parse.(Float64, weather_data[!, "DNI"]),
                "DHI" => parse.(Float64, weather_data[!, "DHI"]),
                "GHI" => parse.(Float64, weather_data[!, "GHI"]),
                "Temperature" => parse.(Float64, weather_data[!, "Temperature"]),
                "Wind Speed" => parse.(Float64, weather_data[!, "Wind Speed"]),
                after=true,
            )
        catch e
            throw(
                ErrorException(
                    "The provided weather data does not contain the expected " *
                    "information. Please try again.",
                ),
            )
        end
    catch e
        throw(
            ErrorException(
                "Weather data not found in the specified location. Please try again.",
            ),
        )
    end

    # Check the problem type
    if lowercase(scenario["problem_type"]) in ["production_cost", "pcm"]
        scenario["problem_type"] = "pcm"
    elseif lowercase(scenario["problem_type"]) in ["capacity_expansion", "cem"]
        scenario["problem_type"] = "cem"
    else
        throw(
            ErrorException(
                "The problem type must be either production_cost or " *
                "capacity_expansion. Please try again.",
            ),
        )
    end

    # Check the interval length
    if lowercase(scenario["interval_length"]) in ["hour"]
        scenario["interval_length"] = uppercase(scenario["interval_length"])
    else
        throw(
            ErrorException(
                "Only interval lengths of one hour are supported at this time. Please " *
                "try again.",
            ),
        )
    end

    # Check the optimization horizon
    if lowercase(scenario["optimization_horizon"]) in ["day", "month", "year"]
        scenario["optimization_horizon"] = uppercase(scenario["optimization_horizon"])
    else
        throw(
            ErrorException(
                "The optimization horizon must be either a day, month, or year. Please " *
                "try again.",
            ),
        )
    end

    # Check the optimization solver
    if lowercase(scenario["optimization_solver"]) in ["glpk", "gurobi", "highs"]
        scenario["optimization_solver"] = lowercase(scenario["optimization_solver"])
    else
        throw(
            ErrorException(
                "DERIVE does not support " *
                scenario["optimization_solver"] *
                " as a solver. Please try again.",
            ),
        )
    end

    # Convert Dict to NamedTuple
    scenario = (; (Symbol(k) => v for (k, v) in scenario)...)

    # Convert NamedTuple to Scenario object
    scenario = Scenario(; scenario...)

    return scenario
end
