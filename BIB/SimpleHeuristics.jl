abstract type QS_table_policy <: Policy end

#########################################
#               QMDP:
#########################################

@kwdef struct QMDPSolver_alt <: Solver
    precision::AbstractFloat    = 1e-3
    max_time::Float64           = 600
    max_iterations::Int         = 5_000
end

struct QMDPPlanner_alt <: QS_table_policy
    Model::POMDP
    Q::Matrix{AbstractFloat}
    V::Vector{AbstractFloat}
end

get_max_r(m::POMDP) = get_max_r(m,states(m), actions(m))
function get_max_r(m,S, A)
    maxr = 0
    for s in S
        for a in A
            maxr = max(maxr, reward(m,s,a))
        end
    end
    return maxr 
end


"""Computes the QMDP table using value iteration"""
function solve(sol::QMDPSolver_alt, m::POMDP; Data=nothing)
    t0 = time()
    if Data isa Nothing
        C = get_constants(m)
        S_dict = Dict( zip(C.S, 1:C.ns))
    else
        C, S_dict = Data.constants, Data.S_dict
    end

    Q = zeros(C.ns,C.na)
    Qmax = zeros(C.ns)
    max_r = get_max_r(m,C.S, C.A)
    maxQ = max_r / (1-discount(m))
    Q[:,:] .= maxQ
    Qmax[:] .= maxQ

    i=0
    # Lets iterate!
    largest_change = Inf
    i=0

    while (largest_change > sol.precision) && (i < sol.max_iterations)
        i+=1
        largest_change = 0
        for (si,s) in enumerate(C.S)
            for (ai,a) in enumerate(C.A)
                Qnext = reward(m,s,a)
                thisT = transition(m,s,a)
                for sp in support(thisT)
                    Qnext += pdf(thisT, sp) * discount(m) * Qmax[S_dict[sp]]
                end
                largest_change = max(largest_change, abs((Qnext - Q[si,ai]) / (Q[si,ai]+1e-10) ))
                Q[si,ai] = Qnext
            end
            Qmax[si] = maximum(Q[si,:])
        end
        time()-t0 > sol.max_time && break
    end
    
    return QMDPPlanner_alt(m,Q,Qmax)
end

#########################################
#               FIB:
#########################################

@kwdef struct FIBSolver_alt <: Solver
    precision::AbstractFloat    = 1e-4
    max_time::Float64           = 600
    max_iterations::Int         = 1000
end

struct FIBPlanner_alt <: QS_table_policy
    Model::POMDP 
    Q::Matrix{AbstractFloat}
    V::Vector{AbstractFloat}
    constants::C
    S_dict
end


POMDPs.solve(sol::FIBSolver_alt, m::POMDP) = solve(sol,m;Data=nothing)

function solve(sol::FIBSolver_alt, m::POMDP; Data = nothing)
    # Pre-computations
    t0 = time()
    if Data isa Nothing
        C = get_constants(m)
        S_dict = Dict( zip(C.S, 1:C.ns))

        SAO_probs, SAOs = get_all_obs_probs(m; constants=C)
        B, B_idx = get_belief_set(m, SAOs; constants=C)
        Q = solve(QMDPSolver_alt(precision=sol.precision, max_iterations=sol.max_iterations), m).Q
    else
        C, S_dict, SAO_probs, SAOs = Data.constants, Data.S_dict, Data.SAO_probs, Data.SAOs
        B, B_idx, Q = Data.B, Data.B_idx, Data.Q
        Q isa Nothing && (Q = solve(QMDPSolver_alt(precision=sol.precision, max_iterations=sol.max_iterations), m; Data).Q)
    end

    γ = discount(m)

    largest_change = Inf
    i=0
    while (largest_change > sol.precision) && (i < sol.max_iterations)
        i+=1
        largest_change = 0
        for (si,s) in enumerate(C.S)
            for (ai,a) in enumerate(C.A)
                thisQ = reward(m,s,a)
                for oi in SAOs[si, ai]
                    bnext_idx = B_idx[si,ai,oi]
                    bnext = B[bnext_idx]
                    Qo = zeros(C.na)
                    for s in support(bnext)
                        Qo = Qo .+ ( pdf(bnext, s) .* Q[S_dict[s], :])
                    end
                    thisQ += γ * SAO_probs[oi,si,ai] * maximum(Qo)
                end
                largest_change = max(largest_change, abs((thisQ - Q[si,ai]) / (Q[si,ai]+1e-5) ))
                Q[si,ai] = thisQ
            end
        end
        time()-t0 > sol.max_time && break
    end
    return FIBPlanner_alt(m,Q, vec(maximum(Q, dims=2)),C,S_dict) ### dim?
end

#########################################
#            Values & actions:
#########################################

function action_value(π::X,b) where X<: QS_table_policy
    M = π.Model
    thisQ = zeros(π.constants.na)
    for ai in 1:π.constants.na
        for s in support(b)
            si = π.S_dict[s]
            thisQ[ai] += pdf(b,s) * π.Q[si,ai]
        end
    end 
    aimax = argmax(thisQ)
    return (π.constants.A[aimax], thisQ[aimax])
end

POMDPs.action(π::X,b) where X<: QS_table_policy = first(action_value(π,b))
POMDPs.value(π::X,b) where X<: QS_table_policy = last(action_value(π,b))

function get_heuristic_pointset(policy::X) where X<:QS_table_policy
    return policy.V, [], [] # hopefully the order is correct...
end