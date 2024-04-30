"""
    adjust_demand_profiles(scenario::Scenario, demand::Demand)::Demand

Adjusts the provided demand profile to have the proper time stamps and to have time 
increments as specified by the user. If the demand profile needs to be expanded (due to the 
provided demand profile having a finer time increment), then linear interpolation is used. 
If the demand profile needs to be reduced (due to the provided demand profile having a 
coarser time increment), then averaging between proper time steps is used.
"""
function adjust_demand_profiles(scenario::Scenario, demand::Demand)::Demand
    # Initialize the updated Demand struct object
    demand_ = Dict{String,Any}(string(i) => getfield(demand, i) for i in fieldnames(Demand))
    println("...preparing demand profiles")

    # Adjust the time stamps in the demand profile
    demand_["demand_profile"] = DataFrames.DataFrame(
        "timestamp" => collect(
            Dates.DateTime(scenario.year, 1, 1, 0, 0):Dates.Minute(
                scenario.interval_length,
            ):Dates.DateTime(scenario.year, 12, 31, 23, 45),
        ),
        "demand" => check_and_update_demand_profile(scenario, demand.demand_profile),
    )

    # Adjust the time stamps in the flexible demand profiles, if applicable
    for i in ["up", "down"]
        if !isnothing(demand_["shift_" * i * "_capacity_profile"])
            demand_["shift_" * i * "_capacity_profile"] = DataFrames.DataFrame(
                "timestamp" => collect(
                    Dates.DateTime(scenario.year, 1, 1, 0, 0):Dates.Minute(
                        scenario.interval_length,
                    ):Dates.DateTime(scenario.year, 12, 31, 23, 45),
                ),
                "demand" => check_and_update_demand_profile(
                    scenario,
                    getproperty(demand, Symbol("shift_" * i * "_capacity_profile")),
                ),
            )
        end
    end

    # Convert Dict to NamedTuple
    demand_ = (; (Symbol(k) => v for (k, v) in demand_)...)

    # Convert NamedTuple to Demand object
    demand_ = Demand(; demand_...)

    return demand_
end

"""
    check_and_update_demand_profile(
        scenario::Scenario,
        original_demand_profile::DataFrames.DataFrame,
    )::Vector{Float64}

Determines whether or not the demand profile is already of the correct length. If so, the 
provided demand profile data is returned. If not, the demand profile data is reduced or 
expanded prior to being returned.
"""
function check_and_update_demand_profile(
    scenario::Scenario,
    original_demand_profile::DataFrames.DataFrame,
)::Vector{Float64}
    # Check the length of the demand profile; update the profile as needed
    if size(original_demand_profile, 1) in
       [Dates.daysinyear(scenario.year) * 24 * i for i in [1, 2, 4]]
        if size(original_demand_profile, 1) ==
           (Dates.daysinyear(scenario.year) * 24 * 60 / scenario.interval_length)
            # Return the existing demand profile data if it is already of the correct length
            return original_demand_profile[!, "demand"]
        elseif size(original_demand_profile, 1) >
               (Dates.daysinyear(scenario.year) * 24 * 60 / scenario.interval_length)
            # Return a demand profile that has been reduced by averaging between time steps
            return reduce_demand_profile(
                scenario,
                original_demand_profile,
                floor(
                    Int64,
                    size(original_demand_profile, 1) /
                    (Dates.daysinyear(scenario.year) * 24 * 60 / scenario.interval_length),
                ),
            )
        else
            # Return a demand profile that has been extended using linear interpolation
            return expand_demand_profile(
                scenario,
                original_demand_profile,
                floor(
                    Int64,
                    (Dates.daysinyear(scenario.year) * 24 * 60 / scenario.interval_length) /
                    size(original_demand_profile, 1),
                ),
            )
        end
    else
        throw(
            ErrorException(
                "The provided demand profile does not have a complete set of time steps. " *
                "Please try again.",
            ),
        )
    end
end

"""
    reduce_demand_profile(
        scenario::Scenario,
        original_demand_profile::DataFrames.DataFrame,
        time_step_diff::Int64,
    )::Vector{Float64}

Reduces the size of the demand profile data by averaging between the time steps that will 
be subsumed into a single time step.
"""
function reduce_demand_profile(
    scenario::Scenario,
    original_demand_profile::DataFrames.DataFrame,
    time_step_diff::Int64,
)::Vector{Float64}
    # Reduce the size of the provided demand profile according to the time step differential
    if time_step_diff in [2, 4]
        # Preallocate demand profile values with scenario-specified time steps
        demand_profile = zeros(
            floor(
                Int64,
                Dates.daysinyear(scenario.year) * 24 * 60 / scenario.interval_length,
            ),
        )

        # Reduce the provided demand profile by averaging amongst the proper time steps
        for i in eachindex(demand_profile)
            demand_profile[i] =
                sum(
                    original_demand_profile[!, "demand"][((i - 1) * time_step_diff + 1):(i * time_step_diff)],
                ) / time_step_diff
        end

        # Return the updated demand profile
        return demand_profile
    else
        throw(
            ErrorException(
                "The time step differential is invalid. Please check the demand profile " *
                "and try again.",
            ),
        )
    end
end

"""
    expand_demand_profile(
        scenario::Scenario,
        original_demand_profile::DataFrames.DataFrame,
        time_step_diff::Int64,
    )::Vector{Float64}

Expands the size of the demand profile data by using linear interpolation between the 
existing time steps.
"""
function expand_demand_profile(
    scenario::Scenario,
    original_demand_profile::DataFrames.DataFrame,
    time_step_diff::Int64,
)::Vector{Float64}
    # Expand the size of the provided demand profile according to the time step differential
    if time_step_diff in [2, 4]
        # Preallocate demand profile values with scenario-specified time steps
        demand_profile = zeros(
            floor(
                Int64,
                Dates.daysinyear(scenario.year) * 24 * 60 / scenario.interval_length,
            ),
        )

        # Expand the provided demand profile by linearly interpolating between the proper 
        # time steps
        for i in eachindex(original_demand_profile[!, "demand"])
            if i == length(original_demand_profile[!, "demand"])
                demand_profile[((i - 1) * time_step_diff + 1):(i * time_step_diff)] = [
                    original_demand_profile[!, "demand"][i] +
                    (j / time_step_diff) * (
                        original_demand_profile[!, "demand"][1] -
                        original_demand_profile[!, "demand"][i]
                    ) for j = 0:(time_step_diff - 1)
                ]
            else
                demand_profile[((i - 1) * time_step_diff + 1):(i * time_step_diff)] = [
                    original_demand_profile[!, "demand"][i] +
                    (j / time_step_diff) * (
                        original_demand_profile[!, "demand"][i + 1] -
                        original_demand_profile[!, "demand"][i]
                    ) for j = 0:(time_step_diff - 1)
                ]
            end
        end

        # Return the updated demand profile
        return demand_profile
    else
        throw(
            ErrorException(
                "The time step differential is invalid. Please check the demand profile " *
                "and try again.",
            ),
        )
    end
end
