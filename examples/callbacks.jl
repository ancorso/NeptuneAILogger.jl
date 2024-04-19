using FluxTraining
import FluxTraining:
    Callback, EpochEnd, StepEnd, AbstractValidationPhase, Read, log_to, ValidationPhase
import FluxTraining: Loggables

using DataStructures

"""
    mutable struct BestCheckpointer <: Callback

A mutable struct representing a callback for checkpointing the best model during training.

# Fields
- `folder`: The folder path where the checkpoint files will be saved.
- `metric`: The metric used to determine the best model.
- `comparison`: The comparison operator used to compare the metric values.
- `best_val`: The best metric value obtained so far.
- `save_current`: A flag indicating whether to save the current model as well.
"""
mutable struct BestCheckpointer <: Callback
    folder
    metric
    comparison
    best_val
    save_current
    logger_backend
    function BestCheckpointer(
        folder, metric, comparison, best_val, save_current, logger_backend
    )
        mkpath(folder)
        return new(folder, metric, comparison, best_val, save_current, logger_backend)
    end
end

"Return the name of the checkpoint file. Returns something like 'min_validation_Loss_checkpoint' or 'max_validation_Loss_checkpoint'"
function best_checkpoint_name(checkpointer::BestCheckpointer)
    comp = "unknown_comparison"
    if checkpointer.comparison == <
        comp = "min"
    elseif checkpointer.comparison == >
        comp = "max"
    end
    return string(comp, "_validation_", string(checkpointer.metric), "_checkpoint")
end

# best_checkpoint_name(MinValCheckpointer("test")) == "min_validation_Loss_checkpoint"
# best_checkpoint_name(MaxValCheckpointer("test")) == "max_validation_Loss_checkpoint"

"""
    MinValCheckpointer(folder; metric=:Loss, save_current=true)

Create a checkpointer that saves the model with the minimum value of a specified metric.

# Arguments
- `folder::String`: The folder path where the model checkpoints will be saved.
- `metric::Symbol`: The metric to be used for comparison. Default is `:Loss`.
- `save_current::Bool`: Whether to save the current model as well. Default is `true`.

# Returns
A `BestCheckpointer` object that saves the model with the minimum value of the specified metric.
"""
function MinValCheckpointer(folder; metric=:Loss, save_current=true, logger_backend=nothing)
    return BestCheckpointer(folder, metric, <, Inf, save_current, logger_backend)
end

"""
    MinValCheckpointer(folder; metric=:Loss, save_current=true)

Create a checkpointer that saves the model with the maximum value of a specified metric.

# Arguments
- `folder::String`: The folder path where the model checkpoints will be saved.
- `metric::Symbol`: The metric to be used for comparison. Default is `:Loss`.
- `save_current::Bool`: Whether to save the current model as well. Default is `true`.

# Returns
A `BestCheckpointer` object that saves the model with the maximum value of the specified metric.
"""
function MaxValCheckpointer(folder; metric=:Loss, save_current=true, logger_backend=nothing)
    return BestCheckpointer(folder, metric, >, -Inf, save_current, logger_backend)
end

"Set the stateaccess of the BestCheckpointer callback"
FluxTraining.stateaccess(::BestCheckpointer) =
    (model=Read(), cbstate=(metricsepoch=Read(),))

"Saves the best and optinoally the current checkpoint and optionally logs them"
function FluxTraining.on(
    ::EpochEnd, phase::AbstractValidationPhase, checkpointer::BestCheckpointer, learner
)
    metric = last(learner.cbstate.metricsepoch[phase], checkpointer.metric)[2]

    # Optionally save the current model as a checkpoint and optionally log it
    if checkpointer.save_current
        checkpoint_name = best_checkpoint_name(checkpointer)
        current_checkpoint = joinpath(checkpointer.folder, string(checkpoint_name, ".bson"))
        savemodel(learner.model, current_checkpoint)
        if !isnothing(checkpointer.logger_backend)
            log_to(
                checkpointer.logger_backend,
                Loggables.File(current_checkpoint, nothing),
                checkpoint_name,
            )
        end
    end

    # Save the model if the metric is better than the best value so far
    if checkpointer.comparison(metric, checkpointer.best_val)
        checkpointer.best_val = metric
        best_checkpoint = joinpath(checkpointer.folder, "best_checkpoint.bson")
        savemodel(learner.model, best_checkpoint)
        if !isnothing(checkpointer.logger_backend)
            log_to(
                checkpointer.logger_backend,
                Loggables.File(best_checkpoint, nothing),
                "current_checkpoint",
            )
        end
    end
end

struct GenVisuals <: Callback
    folder
    vis_fn
    vis_name
    phase
    logger_backend
    function GenVisuals(
        folder,
        vis_fn;
        vis_name="visualization",
        phase=ValidationPhase,
        logger_backend=nothing,
        freq=100,
    )
        mkpath(folder)
        cb = new(folder, vis_fn, vis_name, phase, logger_backend)
        return isnothing(freq) ? cb : throttle(cb, StepEnd; freq=freq)
    end
end

"Set the stateaccess of the GenVisuals callback"
FluxTraining.stateaccess(::GenVisuals) = (step=Read(), cbstate=(history=Read(),))

"Generates and logs visualizations"
function FluxTraining.on(::StepEnd, phase, cb::GenVisuals, learner)
    !(phase isa cb.phase) && return nothing # Only run on the specified phase

    # Get the epoch/step to construct the filename
    history = learner.cbstate.history[phase]
    epoch = history.epochs
    epoch_folder = joinpath(cb.folder, string("epoch_", epoch))
    mkpath(epoch_folder)

    step = history.steps
    filename = joinpath(epoch_folder, string("step_", step, ".png"))

    # Pass the learner step and filename to the vis_fn
    cb.vis_fn(learner.step; filename)

    # Log the corresponding image
    if !isnothing(cb.logger_backend)
        log_to(
            cb.logger_backend,
            Loggables.Image(filename),
            cb.vis_name,
            step;
            group=("Step", string(typeof(phase)), "Visualizations"),
            name="epoch_$(epoch)_step_$(step)",
        )
    end
end
