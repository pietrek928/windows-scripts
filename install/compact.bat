powercfg /hibernate off
powershell "Disable-ComputerRestore -Drive C:"
vssadmin delete shadows /all /quiet
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

wmic computersystem set AutomaticManagedPagefile=False
wmic pagefileset where name="C:\\pagefile.sys" delete

pause
