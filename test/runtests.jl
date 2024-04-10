using NeptuneAILogger
using Test
using PythonCall
using DataFrames
using Plots

NeptuneAILogger.set_api_token(NeptuneAILogger.neptune.ANONYMOUS_API_TOKEN)

# Test the API token
@test pyconvert(Bool, anonymous_api_token() == NeptuneAILogger.neptune.ANONYMOUS_API_TOKEN)

# Use the quickstart log to test things
lg = NeptuneLogger(; project="common/quickstarts", mode="sync")

## Single value

# Float
lg["v1"] = 0.9
@test pyconvert(Float64, lg["v1"].fetch()) == 0.9

# This overrides the value
lg["v1"] = 1.0
@test pyconvert(Float64, lg["v1"].fetch()) == 1.0

# String
lg["v2"] = "This is a test"
@test pyconvert(String, lg["v2"].fetch()) == "This is a test"

## Multiple values
push!(lg, "v3", 0.1)
push!(lg, "v3", 0.2)
push!(lg, "v3", 0.3)
@test DataFrame(PyTable(lg["v3"].fetch_values())).value == [0.1, 0.2, 0.3]
@test length(lg["v3"].fetch_values()) == 3

push!(lg, "v31", 0.1; step=5)
push!(lg, "v31", 0.2; step=10)
push!(lg, "v31", 0.3; step=15)
@test DataFrame(PyTable(lg["v31"].fetch_values())).value == [0.1, 0.2, 0.3]
@test DataFrame(PyTable(lg["v31"].fetch_values())).step == [5.0, 10.0, 15.0]
@test length(lg["v3"].fetch_values()) == 3

## Upload a file
heatmap(rand(10, 10))
savefig("test.png")
upload(lg, "v4", "test.png")
rm("test.png")

lg["v4"].download()
@test isfile("v4.png")
rm("v4.png")

## Upload a file series
for i in 1:3
    heatmap(rand(10, 10))
    savefig("test$i.png")
    push!(lg, "v5", File("test$i.png"))
    rm("test$i.png")
end

# Check that the files were uploaded
lg["v5"].download()
@test isfile("neptune/v5/0.png")
@test isfile("neptune/v5/1.png")
@test isfile("neptune/v5/2.png")
rm("neptune"; recursive=true)

## Upload file set
mkdir("outputs")
for i in 1:3
    heatmap(rand(10, 10))
    savefig("outputs/test$i.png")
end

upload_files(lg, "v6", "outputs")
rm("outputs"; recursive=true)

lg["v6"].download()
@test isfile("v6.zip")
rm("v6.zip")

close(lg)
