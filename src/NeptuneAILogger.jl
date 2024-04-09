module NeptuneAILogger

using PythonCall

const neptune = PythonCall.pynew()

import PackageExtensionCompat: @require_extensions
function __init__()
  PythonCall.pycopy!(neptune, pyimport("neptune"))

  @require_extensions
end

end # module NeptuneAILogger
