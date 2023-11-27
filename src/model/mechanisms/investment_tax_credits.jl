"""
    define_solar_investment_tax_credit!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        scenario::Scenario,
        solar::Solar,
    )

Adds a "revenue" to the objective function to account for the solar investment tax credit. 
This "revenue" is determined by multiplying the solar investment tax credit percentage by 
the amortized capital cost of the solar photovoltaic (PV) system.
"""
function define_solar_investment_tax_credit!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    scenario::Scenario,
    solar::Solar,
)
    # Reduce the capital cost of the solar PV system by the specified investment tax credit
    if isnothing(solar.investment_tax_credit)
        throw(
            ErrorException(
                "There is no value provided for the solar investment tax credit. Please " *
                "try again.",
            ),
        )
    else
        if isnothing(scenario.discount_rate)
            JuMP.add_to_expression!(
                obj,
                -1 * solar.investment_tax_credit * solar.capital_cost * m[:pv_capacity] /
                solar.lifespan,
            )
        else
            JuMP.add_to_expression!(
                obj,
                -1 *
                (scenario.discount_rate * (1 + scenario.discount_rate)^solar.lifespan) /
                ((1 + scenario.discount_rate)^solar.lifespan - 1) *
                solar.investment_tax_credit *
                solar.capital_cost *
                m[:pv_capacity],
            )
        end
    end
end

"""
    define_storage_investment_tax_credit!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        scenario::Scenario,
        storage::Storage,
    )

Adds a "revenue" to the objective function to account for the storage investment tax 
credit. This "revenue" is determined by multiplying the storage investment tax credit 
percentage by the amortized capital cost of the battery energy storage system.
"""
function define_storage_investment_tax_credit!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
    scenario::Scenario,
    storage::Storage,
)
    # Reduce the capital cost of the battery energy storage system by the specified 
    # investment tax credit
    if isnothing(storage.investment_tax_credit)
        throw(
            ErrorException(
                "There is no value provided for the storage investment tax credit. " *
                "Please try again.",
            ),
        )
    else
        if isnothing(scenario.discount_rate)
            JuMP.add_to_expression!(
                obj,
                -1 *
                storage.investment_tax_credit *
                storage.power_capital_cost *
                m[:bes_power_capacity] / storage.lifespan,
            )
        else
            JuMP.add_to_expression!(
                obj,
                -1 *
                (scenario.discount_rate * (1 + scenario.discount_rate)^storage.lifespan) /
                ((1 + scenario.discount_rate)^storage.lifespan - 1) *
                storage.investment_tax_credit *
                storage.power_capital_cost *
                m[:bes_power_capacity],
            )
        end
    end
end
