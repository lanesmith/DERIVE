"""
    print_derive_header()

Prints the DERIVE header in the typical Julia colorway.
"""
function print_derive_header()
    printstyled("   _____   _____ ____   "; bold=true, color=:blue)
    printstyled("_____"; bold=true, color=:red)
    printstyled(" _    _ "; bold=true, color=:green)
    printstyled("_____ \n"; bold=true, color=:magenta)
    printstyled("  |  __ \\ |  ___|  _ \\ "; bold=true, color=:blue)
    printstyled("|_   _|"; bold=true, color=:red)
    printstyled(" |  | |"; bold=true, color=:green)
    printstyled("  ___| \n"; bold=true, color=:magenta)
    printstyled("  | |  \\ \\| |_  | |_| |"; bold=true, color=:blue)
    printstyled("  | | "; bold=true, color=:red)
    printstyled("| |  | |"; bold=true, color=:green)
    printstyled(" |_    \n"; bold=true, color=:magenta)
    printstyled("  | |   | |  _| |    / "; bold=true, color=:blue)
    printstyled("  | |  "; bold=true, color=:red)
    printstyled("\\ \\/ /"; bold=true, color=:green)
    printstyled("|  _| \n"; bold=true, color=:magenta)
    printstyled("  | |__/ /| |___| |\\ \\ "; bold=true, color=:blue)
    printstyled(" _| |_ "; bold=true, color=:red)
    printstyled(" \\  / "; bold=true, color=:green)
    printstyled("| |___  \n"; bold=true, color=:magenta)
    printstyled("  |_____/ |_____|_| \\_\\"; bold=true, color=:blue)
    printstyled("|_____|"; bold=true, color=:red)
    printstyled("  \\/  "; bold=true, color=:green)
    printstyled("|_____| \n"; bold=true, color=:magenta)
    println("")
    println(
        "  developed by Lane D. Smith | version " *
        TOML.parse(read(abspath(joinpath(@__DIR__, "..", "..", "Project.toml")), String))["version"],
    )
    println("")
    println("")
end
