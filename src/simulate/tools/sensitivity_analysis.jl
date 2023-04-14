"""
    perform_sensitivity_analysis(
        scenario::Scenario,
        tariff::Tariff,
        market::Market,
        incentives::Incentives,
        demand::Demand,
        solar::Solar,
        storage::Storage,
        output_filepath::Union{String,Nothing}=nothing;
        sensitivity_variable::String,
        sensitivity_parameter::String,
        sensitivity_values::Vector{Float64},
    )::Dict

Performs a single-parameter sensitivity analysis as specified by the user. A set of values 
for a single field of a single object are provided over which the function will iteratively 
sweep. Returns the time-series results of each scenario simulation in a dictionary.
"""
function perform_sensitivity_analysis(
    scenario::Scenario,
    tariff::Tariff,
    market::Market,
    incentives::Incentives,
    demand::Demand,
    solar::Solar,
    storage::Storage,
    output_filepath::Union{String,Nothing}=nothing;
    sensitivity_variable::String,
    sensitivity_parameter::String,
    sensitivity_values::Vector{Float64},
)::Dict
    # Check that sensitivity_variable corresponds to a viable DERIVE struct
    if !(
        lowercase(sensitivity_variable) in
        ["tariff", "market", "incentives", "demand", "solar", "storage"]
    )
        throw(
            ErrorException(
                sensitivity_variable *
                " does not refer to a viable object in DERIVE. Please try again.",
            ),
        )
    end

    # Initialize a Dict to hold the time-series results from the sensitivity analysis
    sensitivity_analysis_results = Dict{String,Any}()

    # Iterate through different values provided in the sensitivity range
    for v in sensitivity_values
        scenario_name = sensitivity_variable * "_" * sensitivity_parameter * "_" * string(v)
        println("...running scenario " * scenario_name)

        # Return DERIVE object that corresponds to sensitivity_variable
        if lowercase(sensitivity_variable) == "tariff"
            tariff = update_struct_for_sensitivity_analysis(
                tariff,
                sensitivity_variable,
                sensitivity_parameter,
                v,
            )
        elseif lowercase(sensitivity_variable) == "market"
            market = update_struct_for_sensitivity_analysis(
                market,
                sensitivity_variable,
                sensitivity_parameter,
                v,
            )
        elseif lowercase(sensitivity_variable) == "incentives"
            incentives = update_struct_for_sensitivity_analysis(
                incentives,
                sensitivity_variable,
                sensitivity_parameter,
                v,
            )
        elseif lowercase(sensitivity_variable) == "demand"
            demand = update_struct_for_sensitivity_analysis(
                demand,
                sensitivity_variable,
                sensitivity_parameter,
                v,
            )
        elseif lowercase(sensitivity_variable) == "solar"
            solar = update_struct_for_sensitivity_analysis(
                solar,
                sensitivity_variable,
                sensitivity_parameter,
                v,
            )
        elseif lowercase(sensitivity_variable) == "storage"
            storage = update_struct_for_sensitivity_analysis(
                storage,
                sensitivity_variable,
                sensitivity_parameter,
                v,
            )
        end

        # Perform the simulation
        time_series_results = solve_problem(
            scenario,
            tariff,
            market,
            incentives,
            demand,
            solar,
            storage,
            output_filepath,
        )

        # Update the sensitivity analysis results to include the new timie-series results
        sensitivity_analysis_results[scenario_name] = time_series_results
    end

    # Return the results from the sensitivity analysis
    return sensitivity_analysis_results
end

"""
    update_struct_for_sensitivity_analysis(
        derive_object::Union{Tariff,Market,Incentives,Demand,Solar,Storage},
        sensitivity_variable::String,
        sensitivity_parameter::String,
        new_value::Float64,
    )::Union{Tariff,Market,Incentives,Demand,Solar,Storage}

Update the field of a particular object of a specified type to be the new value provided by 
the sensitivity analysis.
"""
function update_struct_for_sensitivity_analysis(
    derive_object::Union{Tariff,Market,Incentives,Demand,Solar,Storage},
    sensitivity_variable::String,
    sensitivity_parameter::String,
    new_value::Float64,
)::Union{Tariff,Market,Incentives,Demand,Solar,Storage}
    # Check that sensitivity_parameter is a viable field of the struct of derive_object
    if !(Symbol(sensitivity_parameter) in fieldnames(typeof(derive_object)))
        throw(
            ErrorException(
                sensitivity_parameter *
                " is not a viable field of the struct that defines " *
                lowercase(sensitivity_variable) *
                ". Please try again.",
            ),
        )
    end

    # Initialize the updated DERIVE  object
    derive_object_ = Dict{String,Any}(
        string(i) => getfield(derive_object, i) for i in fieldnames(typeof(derive_object))
    )

    # Update the specified field in derive_object to be new_value
    derive_object_[sensitivity_parameter] = new_value

    # Convert Dict to NamedTuple
    derive_object_ = (; (Symbol(k) => v for (k, v) in derive_object_)...)

    # Convert NamedTuple to an object of the appropriate struct
    try
        if lowercase(sensitivity_variable) == "tariff"
            derive_object_ = Tariff(; derive_object_...)
        elseif lowercase(sensitivity_variable) == "market"
            derive_object_ = Market(; derive_object_...)
        elseif lowercase(sensitivity_variable) == "incentives"
            derive_object_ = Incentives(; derive_object_...)
        elseif lowercase(sensitivity_variable) == "demand"
            derive_object_ = Demand(; derive_object_...)
        elseif lowercase(sensitivity_variable) == "solar"
            derive_object_ = Solar(; derive_object_...)
        elseif lowercase(sensitivity_variable) == "storage"
            derive_object_ = Storage(; derive_object_...)
        end
    catch e
        throw(
            ErrorException(
                "The " *
                sensitivity_parameter *
                " field is not of type Float64. Please try again.",
            ),
        )
    end

    # Return the updated object of the desired struct
    return derive_object_
end
