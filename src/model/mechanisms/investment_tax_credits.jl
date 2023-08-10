"""
    define_solar_investment_tax_credit!(m::JuMP.Model, obj::JuMP.AffExpr, solar::Solar)

Adds a "revenue" to the objective function to account for the solar investment tax credit. 
This "revenue" is determined by multiplying the solar investment tax credit percentage by 
the amortized capital cost of the solar photovoltaic (PV) system.
"""
function define_solar_investment_tax_credit!(m::JuMP.Model, obj::JuMP.AffExpr, solar::Solar)
    # Reduce the capital cost of the solar PV system by the specified investment tax credit
    if isnothing(solar.investment_tax_credit)
        throw(
            ErrorException(
                "There is no value provided for the solar investment tax credit. Please " *
                "try again.",
            ),
        )
    else
        JuMP.add_to_expression!(
            obj,
            -1 * solar.investment_tax_credit * solar.capital_cost * m[:pv_capacity] /
            solar.lifespan,
        )
    end
end

"""
    define_storage_investment_tax_credit!(
        m::JuMP.Model,
        obj::JuMP.AffExpr,
        storage::Storage,
    )

Adds a "revenue" to the objective function to account for the storage investment tax 
credit. This "revenue" is determined by multiplying the storage investment tax credit 
percentage by the amortized capital cost of the battery energy storage system.
"""
function define_storage_investment_tax_credit!(
    m::JuMP.Model,
    obj::JuMP.AffExpr,
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
        JuMP.add_to_expression!(
            obj,
            -1 *
            storage.investment_tax_credit *
            storage.power_capital_cost *
            m[:bes_power_capacity] / storage.lifespan,
        )
    end
end
