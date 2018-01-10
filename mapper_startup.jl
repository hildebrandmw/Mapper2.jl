#=
Start script for the Mapper.
=#

using Mapper2
using ArgParse

#=
Set up Argument properties.
=#
function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table s begin
        "profile"
            help = "file path to simulator generated 'profile.json'"
            required = true
        "return"
            help = "path to the desired output file"
            required = true
        "--appname"
            help = "the name of the application"
            required = false
            default = "unknown_application"
    end
    return parse_args(s)
end

function main()
    parsed_args = parse_commandline()

    # Extract the source and destination file names
    profile_path = parsed_args["profile"]::String
    return_path  = parsed_args["return"]::String
    app_name     = parsed_args["appname"]::String

    # Run the mapper
    Mapper2.place_and_route(profile_path, return_path, app_name)
    return 0
end

# Run the main function.
main()
