"""
    read_incentives(filepath::String)::Incentives

Load distributed energy resource (DER) incentive prices and parameters from .csv files 
and return them in an Incentives struct.
"""
function read_incentives(filepath::String)::Incentives
    # Initialize incentives struct
    incentives = Dict{String,Any}(
        "itc_enabled" => false,
        "itc_rate" => nothing,
        "sgip_enabled" => false,
        "sgip_rate" => nothing,
    )

    # Try loading the incentives parameters
    println("...loading incentives parameters")
    try
        incentives_parameters = DataFrames.DataFrame(
            CSV.File(joinpath(filepath, "incentives_parameters.csv"); transpose=true),
        )

        # Try assigning the different incentives parameters from the file
        for k in keys(incentives)
            if !ismissing(incentives_parameters[1, k])
                incentives[k] = incentives_parameters[1, k]
            else
                println(
                    "The " *
                    k *
                    " parameter is not defined. Will default to " *
                    string(incentives[k]) *
                    ".",
                )
            end
        end
    catch e
        println(
            "Incentives parameters not found in " *
            filepath *
            ". Incentives parameters will default to not allowing incentives to be " *
            "considered.",
        )
    end

    # Convert Dict to NamedTuple
    incentives = (; (Symbol(k) => v for (k, v) in incentives)...)

    # Convert NamedTuple to Incentives object
    incentives = Incentives(; incentives...)

    return incentives
end
