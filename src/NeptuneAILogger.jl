module NeptuneAILogger

using PythonCall
using Logging
using DataStructures

const neptune = PythonCall.pynew()

import PackageExtensionCompat: @require_extensions
function __init__()
    PythonCall.pycopy!(neptune, pyimport("neptune"))

    @require_extensions
end

function anonymous_api_token()
    return neptune.ANONYMOUS_API_TOKEN
end

function get_api_token()
    return ENV["NEPTUNE_API_TOKEN"]
end

function set_api_token(token)
    return ENV["NEPTUNE_API_TOKEN"] = token
end

export get_api_token, set_api_token, anonymous_api_token

struct NeptuneLogger <: AbstractLogger
    run::Py
end

"""
  NeptuneLogger(; api_token, project, with_id, mode, name, description, tags, source_files, kwargs...)

Create a logger that logs to Neptune. See the [Neptune api](https://docs.neptune.ai/api/neptune/#init_run) for more information.
"""
function NeptuneLogger(;
    api_token=get_api_token(),
    project,
    with_id=nothing,
    mode="async",
    name=nothing,
    description=nothing,
    tags=[],
    source_files=nothing,
    kwargs...,
)
    run = neptune.init_run(;
        api_token,
        project,
        with_id,
        mode,
        name,
        description,
        tags=pylist(tags),
        source_files,
        kwargs...,
    )
    return NeptuneLogger(run)
end

"""
  File(path)

Create a file object that can be uploaded to Neptune.
"""
struct File
    path::String
end
export File

convert_to_valid_neptune_type(v) = v
convert_to_valid_neptune_type(v::T) where {T<:AbstractArray} = string(v)
convert_to_valid_neptune_type(v::T) where {T<:Tuple} = string(v)

function convert_to_valid_neptune_type(v::Dict)
    new_dict = Dict()
    for (k, v) in v
        new_dict[k] = convert_to_valid_neptune_type(v)
    end
    return new_dict
end

function convert_to_valid_neptune_type(v::OrderedDict)
    new_dict = OrderedDict()
    for (k, v) in v
        new_dict[k] = convert_to_valid_neptune_type(v)
    end
    return new_dict
end

Base.getindex(logger::NeptuneLogger, key) = logger.run[key]

function Base.setindex!(logger::NeptuneLogger, value, key)
    return (logger.run[key] = convert_to_valid_neptune_type(value))
end

function upload(logger::NeptuneLogger, key, file; kwargs...)
    return logger.run[key].upload(file; kwargs...)
end

function upload(logger::NeptuneLogger, key, file::File; kwargs...)
    return logger.run[key].upload(file.path; kwargs...)
end

function Base.push!(logger::NeptuneLogger, key, value; kwargs...)
    return logger.run[key].append(value; kwargs...)
end

function Base.push!(logger::NeptuneLogger, key, file::File; kwargs...)
    return push!(logger, key, neptune.types.File(file.path); kwargs...)
end

upload_files(logger::NeptuneLogger, key, files) = logger.run[key].upload_files(files)

track_files(logger::NeptuneLogger, key, files) = logger.run[key].track_files(files)

Base.close(logger::NeptuneLogger) = logger.run.stop()

id(logger::NeptuneLogger) = pyconvert(String, logger.run["sys/id"].fetch())

export NeptuneLogger, upload, upload_files, track_files, id

struct NeptuneBackend
    logger::NeptuneLogger

    NeptuneBackend(; kwargs...) = new(NeptuneLogger(; kwargs...))
end

export NeptuneBackend

end # module NeptuneAILogger
