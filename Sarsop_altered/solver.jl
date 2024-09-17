Base.@kwdef struct SARSOPSolver{LOW,UP} <: Solver
    epsilon::Float64        = 0.5
    precision::Float64      = 1e-3
    kappa::Float64          = 0.1
    delta::Float64          = 1e-1
    max_time::Float64       = 1.0
    max_steps::Int          = typemax(Int)
    verbose::Bool           = false
    init_lower::LOW         = BlindLowerBound(bel_res = 1e-2)
    init_upper::UP          = FastInformedBound(bel_res=1e-2)
    prunethresh::Float64    = 0.10
    heuristic_solver::Union{Nothing,Solver} = nothing
    add_to_pointset::Bool   = false
end

function POMDPTools.solve_info(solver::SARSOPSolver, pomdp::POMDP)
    t0 = time()
    tree = SARSOPTree(solver, pomdp)
    
    if solver.verbose
        initialize_verbose_output()
    end
    
    iter = 0
    times, ubs, lbs = [], [], []
    push!(times, time()-t0)
    push!(ubs, tree.V_upper[1])
    push!(lbs, tree.V_lower[1])
    while time()-t0 < solver.max_time && root_diff_normalized(tree) > solver.precision
        sample!(solver, tree)
        backup!(tree)
        prune!(solver, tree)
        if solver.verbose && iter % 10 == 0
            log_verbose_info(t0, iter, tree)
        end

        push!(times, time()-t0)
        push!(ubs, tree.V_upper[1])
        push!(lbs, tree.V_lower[1])
        iter += 1
    end
    is_timed_out = root_diff_normalized(tree) > solver.precision

    if solver.verbose 
        dashed_line()
        log_verbose_info(t0, iter, tree)
        dashed_line()
    end
    
    pol = AlphaVectorPolicy(
        pomdp,
        getproperty.(tree.Γ, :alpha),
        ordered_actions(pomdp)[getproperty.(tree.Γ, :action)]
    )
    # return pol, (;
    #     time = time()-t0, 
    #     tree,
    #     iter
    # )
    return pol, (time=time()-t0, value=tree.V_upper[1], ubs = ubs, lbs = lbs, times = times, timeout=is_timed_out, iterations=iter)
end

POMDPs.solve(solver::SARSOPSolver, pomdp::POMDP) = first(solve_info(solver, pomdp))

function initialize_verbose_output()
    dashed_line()
    @printf(" %-10s %-10s %-12s %-12s %-15s %-10s %-10s\n", 
        "Time", "Iter", "LB", "UB", "Precision", "# Alphas", "# Beliefs")
    dashed_line()
end

function log_verbose_info(t0::Float64, iter::Int, tree::SARSOPTree)
    @printf(" %-10.2f %-10d %-12.7f %-12.7f %-15.10f %-10d %-10d\n", 
        time()-t0, iter, tree.V_lower[1], tree.V_upper[1], root_diff(tree), 
        length(tree.Γ), length(tree.b_pruned) - sum(tree.b_pruned))
end

function dashed_line(n=86)
    @printf("%s\n", "-"^n)
end
