# Simulated Annealing

```@docs
SA.place!
```

## SAState

```@docs
SA.SAState
```

## Warming

Warming involve increasing the temperature of the simulated annealing system
until certain criteria are reached, at which the true simulated annealing
algorithm takes place. It is important to begin a placement at a high 
temperature because this early phase is responsible for creating a high level 
idea for what the final placement will look like. 

The default implementation described below heats up the the system until a 
certain high fraction of generated moves are accepted, allowing the initial 
temperature to depend on the specific characteristics of the architecture and
taskgraph being placed.

```@docs
SA.SAWarm
SA.warm!
SA.DefaultSAWarm
```

## Cooling

Over the course of simulated annealing placement, the temperature of the system
is slowly lowered, increasing the probability that an objective-increasing move
will be rejected. The simplest is multiplying the temperature by a common factor
``\alpha < 1`` so

```math
T_{new} = \alpha T_{old}.
```

Rasing the value of ``\alpha`` results in higher quality results at the cost
of a longer run time.

```@docs
SA.SACool
SA.cool!
SA.DefaultSACool
```

## Move Distance Limiting

TODO

```@docs
SA.SALimit
SA.limit!
SA.DefaultSALimit
```

## Terminating Placement

TODO

```@docs
SA.SADone
SA.sa_done
SA.DefaultSADone
```
