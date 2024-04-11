module NeptuneAIFluxTrainingExt

using NeptuneAILogger
using FluxTraining
import FluxTraining: Loggables, _combinename, cpu

"Log a value in a series"
function FluxTraining.log_to(
    backend::NeptuneBackend, value::Loggables.Value, name, i; group=()
)
    name = _combinename(name, group)
    return push!(backend.logger, name, value.data)
end

"Log a file in a series"
function FluxTraining.log_to(
    backend::NeptuneBackend, file::Loggables.File, name, i; group=(), kwargs...
)
    name = _combinename(name, group)
    return push!(backend.logger, name, File(file.file); kwargs...)
end

"Log an individual file for folder"
function FluxTraining.log_to(backend::NeptuneBackend, file::Loggables.File, name; kwargs...)
    # check if the file is actually a folder
    if isdir(file.file)
        return upload_files(backend.logger, name, file.file; kwargs...)
    end
    return upload(backend.logger, name, File(file.file); kwargs...)
end

"Log an image in a series"
function FluxTraining.log_to(
    backend::NeptuneBackend, image::Loggables.Image, name, i; group=(), kwargs...
)
    name = _combinename(name, group)
    return push!(backend.logger, name, File(image.data); kwargs...)
end

"Log an individual image"
function FluxTraining.log_to(backend::NeptuneBackend, image::Loggables.Image, name; kwargs...)
    return upload(backend.logger, name, File(image.data); kwargs...)
end

"Log a text in a series"
function FluxTraining.log_to(
    backend::NeptuneBackend, text::Loggables.Text, name, i; group=(), kwargs...
)
    name = _combinename(name, group)
    return push!(backend.logger, name, text.data; kwargs...)
end

"Log a histogram in a series"
function FluxTraining.log_to(
    backend::NeptuneBackend, hist::Loggables.Histogram, name, i; group=()
)
    return error("Not Implemented")
end

end
