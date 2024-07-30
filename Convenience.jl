function breward(model::POMDP, b::DiscreteHashedBelief,a)
    r = 0.0
    for (s,p) in zip(b.state_list, b.probs)
        s == POMDPTools.ModelTools.TerminalState() || ( r += p * POMDPs.reward(model,s,a) )
    end
    return r
end
# POMDPs.reward(model::POMDP, b::DiscreteHashedBelief,a) = sum( (s,p) ->  p * POMDPs.reward(model,s,a), zip(b.state_list, b.probs); init=0.0)

function add_to_dict!(dict, key, value; func=+, minvalue=0)
    if haskey(dict, key)
        dict[key] = func(dict[key], value)
    elseif isnothing(minvalue) || value > minvalue
        dict[key] = value
    end
end



function get_pointset_Sarsop(model::POMDP,π::X) where X<:BIBPolicy
    Bs, Vs = [], []
    for (bi, b) in enumerate(π.Data.B)
        push!(Bs, to_sparse_vector(model,b))
        push!(Vs, maximum(π.Data.Q[bi]))
    end
    return Bs, Vs
end