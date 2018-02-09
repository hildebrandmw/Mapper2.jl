# Mapper2

Welcome to the Mapper2 project. This program was originally intended to serve
as a CAD tool for application development for the KiloCore and KiloCore2 
many-core processors, and has since morphed into a more generalized mapping
tool allowing flexible, high speed mappings to arbitrary topologies in arbitrary
dimensions (with some caveats of course).

This is still very much a work in progress and nothing is guaranteed.

## Installation

This package is not a registered Julia package. To install, run the command
```julia
Pkg.clone("https://github.com/hildebrandmw/Mapper2.jl")
```
All dependent packages should be installed. To verify the installation, run
the command:
```julia
Pkg.test("Mapper2")
```

## Building the Documentation

Install the Documenter package with the command
```
Pkg.add("Documenter")
```
Once that is installed, use a console window to navigate to the *docs/* 
directory and run the command
```
julia --color=yes make.jl
```
Then, navigate into *docs/build* and open `index.html`.

## TODO LIST

### DOCUMENTATION
* General Docs
* Architecture/Constructors.jl
* MapType/\*
* Placement
* Routing

### Tests
Improve Coverage. Begin testing more rigorously for errors during architecture
creating. 

Determine how to reports errors during placement and routing that are 
transparent to programs using this package.

### TODO (B = Basic, M = Medium, H = Hard)
*   Code Coverage Tests:
    - More thoroughly test bipartite matching algorithm.
    - Include tests that exercise various error checking routines in the routing
    verification process.

*   (M) May be some changes to make to routing. Perhaps an equivalence class
    trick like is used in placement to classify what architecture links can be 
    used by a given taskgraph link.

*   (H) Add placement and routing support for fanout networks.

*   (B) Replace debug statements with a Base.logging or some logging package.
    Reason: Reduce code bloat, probably faster. Offload worrying about different
    priority levels to another piece of code.

*   (B) Redo plotting - either by wrapping Plot statements inside a macro to
    diable them or by providing some kind of callback functionality to get all
    kinds of plotting outside of the base mapper.
