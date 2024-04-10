
using MLUtils
import MLDatasets: MNIST
using Flux
using FluxTraining
using ParameterSchedulers: Sequence, Shifted, Sin
using NeptuneAILogger

# Prepare the datasets
const LABELS = 0:9

function preprocess((data, targets))
    return unsqueeze(data, 3), Flux.onehotbatch(targets, LABELS)
end

traindata = preprocess(MNIST(Float32, :train)[:])
testdata = preprocess(MNIST(Float32, :test)[:])

trainloader = DataLoader(traindata; batchsize=128);
testloader = DataLoader(testdata; batchsize=128);

# Define the model, loss, and optimizer
model = Chain(Flux.flatten, Dense(28^2, 32, relu), Dense(32, 10))
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

# TODO: Visualization function (on log end)
function viz(step)
    return println("contents of step: ", keys(step))
end

# TODO: Log the configuration file 

# Define the learner with appropriate callbacks
learner = Learner(
    model,
    lossfn;
    callbacks=[
        Scheduler(LearningRate => schedule),
        Metrics(accuracy),
        # Checkpointer("checkpoints", keep_top_k=1), #TODO: Replace with improved logger
        LogMetrics(neptune),
        LogHyperParams(neptune),
        # LogVisualization(viz, neptune, freq=100), #TODO: Replace with improved logger
    ],
    optimizer,
)

# Fit and then close
FluxTraining.fit!(learner, 10, (trainloader, testloader))

# Don't forget to close the logger
close(neptune.logger)
