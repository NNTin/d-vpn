```pwsh
PS /home/nntin/git/d-vpn> Install-Module -Name PowerShellGet -Force -SkipPublisherCheck
PS /home/nntin/git/d-vpn> Install-Module -Name Pester -Force -AllowClobber
PS /home/nntin/git/d-vpn> Get-Module -Name Pester -ListAvailable

PS /home/nntin/git/d-vpn> pwsh ./tests/WireGuardStartup.Tests.ps1                      

Starting discovery in 1 files.
Discovery found 1 tests in 189ms.
Running tests.
[+] /home/nntin/git/d-vpn/tests/WireGuardStartup.Tests.ps1 615ms (214ms|238ms)
Tests completed in 630ms
Tests Passed: 1, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
```