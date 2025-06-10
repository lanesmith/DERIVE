"""
    store_tiered_energy_results!(
        m::JuMP.Model,
        tiered_energy_results::Dict,
        month_num::Union{Int64,Nothing}=nothing,
        day_num::Union{Int64,Nothing}=nothing,
    )

Store and update the Dict that contains the total net consumption in each tier of the 
tiered energy rate.
"""
function store_tiered_energy_results!(
    m::JuMP.Model,
    tiered_energy_results::Dict,
    month_num::Union{Int64,Nothing}=nothing,
    day_num::Union{Int64,Nothing}=nothing,
)
    # Store the tiered energy results according to whether the optimization horizon is over 
    # one month or one day
    if !isnothing(month_num)
        if !isnothing(day_num)
            tiered_energy_results[string(month_num) * "-" * string(day_num)] =
                JuMP.value.(m[:e_tier])
        else
            tiered_energy_results[string(month_num)] = JuMP.value.(m[:e_tier])
        end
    end
end
