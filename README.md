# Mapper2

[![Build Status](https://travis-ci.org/hildebrandmw/Mapper2.jl.svg?branch=master)](https://travis-ci.org/hildebrandmw/Mapper2.jl)

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

```julia
Pkg.add("Documenter")
```
Once that is installed, use a console window to navigate to the *docs/*
directory and run the command

```bash
julia --color=yes make.jl
```

Then, navigate into *docs/build* and open `index.html`. Note: Docs are a WIP.
