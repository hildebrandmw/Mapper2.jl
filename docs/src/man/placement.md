# Placement
Placement can be fine-tuned for architectures by overloading the methods below.

- *Dispatch Methods* are methods that control which placement algorithm is going
    to be used for a given architecture. If you implement your own algorithm,
    you can control dispatch by overloading this method for your type.

- *Major Methods* can be defined to give a higher degree of control over how
    tasks in your architecture may be mapped to component. These methods 
    influence the creation of specialized Placement Structs.

- *Minor Methods* are defined to control aspects of placement such as objective
    function, node cost, etc. See documentation on specific placement algorithms
    for methods to overload.

# Dispatch Methods

    placement_algorithm(m::Map{A}) where {A <: AbstractArchitecture}

Return the placement structure for architecture `A`. *Default:* `SAStruct(m)`.

# Major Methods

    ismappable(::Type{T}, c::Component)::Bool

Given a component `c`, return whether or not tasks may be mapped to `c`.
*Default:* `true`

    isspecial(::Type{T}, t::TaskgraphNode)::Bool 

Return `true` if `t` is a special task and should be moved using direct look
up tables. *Default:* `false`.

    isequivalent(::Type{T}, a::TaskgraphNode, b::TaskgraphNode)::Bool    

Return `true` if the sets of component to which `a` and `b` can be mapped are
the same. *Default:* `true`

    canmap(::Type{T}, a::TaskgraphNode, c::Component)::Bool

Return `true` if `a` can be mapped to `c`. *Default:* `true`.
