module NeptuneAIFluxTrainingExt

using NeptuneAILogger
using FluxTraining
import FluxTraining: Loggables, _combinename, cpu

function FluxTraining.log_to(
    backend::NeptuneBackend, value::Loggables.Value, name, i; group=()
)
    name = _combinename(name, group)
    return push!(backend.logger, name, value.data)
end

function FluxTraining.log_to(
    backend::NeptuneBackend, image::Loggables.Image, name, i; group=()
)
    name = _combinename(name, group)
    return push!(backend.logger, name, File(image.data))
end

function FluxTraining.log_to(
    backend::NeptuneBackend, text::Loggables.Text, name, i; group=()
)
    name = _combinename(name, group)
    return push!(backend.logger, name, text.data)
end

function FluxTraining.log_to(
    backend::NeptuneBackend, hist::Loggables.Histogram, name, i; group=()
)
    return error("Not Implemented")
end

end
