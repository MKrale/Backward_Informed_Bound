module BIB
    using POMDPs, POMDPTools, Random, Distributions, JuMP
    import HiGHS
    

    printdb(x) = print(x,"\n")
    function printdb(x,y...)
        print(x,", ")
        printdb(y...)
    end

    include("QMDP_alt.jl") # This was easier than using the POMDP standard QMDP, which uses alpha-vectors for some reason...
    include("Beliefs.jl")
    include("solver.jl")
    include("Convenience.jl")

    export
    
    # Convenience:

    # Beliefs:
    DiscreteHashedBelief, DiscreteHashedBeliefUpdater, update,

    #Solver:
    SBIBSolver, WBIBSolver, solve,
    SBIBPolicy, WBIBPolicy, action, bvalue
    
end