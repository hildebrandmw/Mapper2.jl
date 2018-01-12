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
