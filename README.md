# NeptuneAILogger.jl
Unoffical logging for [neptune.ai](https://neptune.ai) in julia. Pull requests welcome.

## Usage

Set your Neptune API Token (this just sets the `ENV[NEPTUNE_API_TOKEN]` variable). For example use provided anonymous api token
```
set_api_token(anonymous_api_token())
```

Create a logger. See the [Neptune api](https://docs.neptune.ai/api/neptune/#init_run) for more information.
```
lg = NeptuneLogger(project="acorso/Test")
```

### Single Value
Log a single value (e.g. hyperparameters)
```
lg["FloatExample"] = 0.9
lg["StringExample"] = "this is a test"
```


### Multiple Values
Log multiple values in sequence to the same variable name (e.g. for metrics)
```
push!(lg, "accuracy", 0.1)
push!(lg, "accuracy", 0.2)
push!(lg, "accuracy", 0.3)
```


### Upload a File
Upload a single file that has been saved to disk via filepath
```
heatmap(rand(10, 10))
savefig("test.png")
upload(lg, "ImageExample", "test.png")
```

### Upload a File Series
Files can be uploaded sequentially as well via filepaths. Requires pushing objects of type `File`. 

```
for i=1:3
    heatmap(rand(10, 10))
    savefig("test$i.png")
    push!(lg, "v5", File("test$i.png"))
end
```

### Upload a File Set
Upload a bunch of files in one fell swoop. Suppose we had a folder `outputs/`, then to upload the contents of that folder call
```
upload_files(lg, "v6", "outputs")
```

### Closing logger
When finished, close the logger:
```
close(lg)
```

## FluxTraining.jl LoggerBackend
A backend for FluxTraining.jl is implemented as an extension. See `examples/flux_training_example.jl` to see how this is used. 

## Acknowledgements
This package was inspired by [Wandb.jl](https://github.com/avik-pal/Wandb.jl).
