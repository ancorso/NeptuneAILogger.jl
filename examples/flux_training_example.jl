using MLUtils
import MLDatasets: MNIST
using Flux
using FluxTraining
using ParameterSchedulers: Sequence, Shifted, Sin
using NeptuneAILogger
using Plots
include("callbacks.jl")

# Define a configuration
config = Dict(
    "hidden_dims" => 32, "batch_size" => 128, "epochs" => 10, "save_dir" => "runs"
)

# Prepare the datasets
const LABELS = 0:9

function preprocess((data, targets))
    return unsqueeze(data, 3), Flux.onehotbatch(targets, LABELS)
end

traindata = preprocess(MNIST(Float32, :train)[:])
testdata = preprocess(MNIST(Float32, :test)[:])

batchsize = config["batch_size"]
trainloader = DataLoader(traindata; batchsize);
testloader = DataLoader(testdata; batchsize);

# Define the model, loss, and optimizer
hdims = config["hidden_dims"]
model = Chain(Flux.flatten, Dense(28^2, hdims, relu), Dense(hdims, 10))
lossfn = Flux.Losses.logitcrossentropy
optimizer = Flux.ADAM();

# Define a hyperparameter scheduler
es = length(trainloader)     # number of steps in an epoch
schedule = Sequence(
    Sin(;
        λ0=0.01, # initial learning rate
        λ1=0.1, # max learning rate
        period=2 * 3es, #
    ) => 3es,
    Shifted(Sin(;
        λ0=0.1, # max learning rate
        λ1=0.001, # end learning rate
        period=2 * 7es,
    ), 7es + 1) => 7es,
)

# Setup the logging
set_api_token(anonymous_api_token()) # NOTE: Set you desired API Token
neptune = NeptuneBackend(; project="acorso/Test")

# Pull out the id of the run
dir = joinpath(config["save_dir"], id(neptune.logger))
mkpath(dir)

# Log the configuration
neptune.logger["configuration"] = config

function viz(step; filename)
    p = heatmap(rand(10, 10))
    return savefig(p, filename)
end

# Define the learner with appropriate callbacks
learner = Learner(
    model,
    lossfn;
    callbacks=[
        Scheduler(LearningRate => schedule),
        Metrics(accuracy),
        MinValCheckpointer(joinpath(dir, "checkpoints"); logger_backend=neptune),
        LogMetrics(neptune),
        LogHyperParams(neptune),
        GenVisuals(joinpath(dir, "visuals"), viz; freq=10, logger_backend=neptune),
    ],
    optimizer,
)

# Fit and then close
FluxTraining.fit!(learner, config["epochs"], (trainloader, testloader))

# Don't forget to close the logger
close(neptune.logger)
