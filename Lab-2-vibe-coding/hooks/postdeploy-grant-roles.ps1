# Wrapper invoked by azd `hooks.postdeploy` in azure.yaml.
# azd disallows hook paths that escape the project root, so we keep a tiny
# in-project file that delegates to the workshop-wide grant script.
& "$PSScriptRoot\..\..\scripts\grant-agent-runtime-roles.ps1" @args
exit $LASTEXITCODE
