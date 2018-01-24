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

### Code
*   (M) Provide some analysis routines for architecture to detect unconnected 
    ports and such. Would help with architecture modeling.

*   (M) May be some changes to make to routing. Perhaps an equivalence class
    trick like is used in placement to classify what architecture links can be 
    used by a given taskgraph link.

*   (B) Add placement and routing support for fanout networks.
