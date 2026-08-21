# Windows 7 compatibility evidence

1. Microsoft Learn, `WaitOnAddress`: https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitonaddress. The page lists the minimum supported client as Windows 8 and the DLL as `API-MS-Win-Core-Synch-l1-2-0.dll`.

2. GitHub project `cristianadam/api-ms-win-core-synch-Win7`: https://github.com/cristianadam/api-ms-win-core-synch-Win7. Its README states that it allows Qt Creator MinGW releases to run on Windows 7 by placing replacement `api-ms-win-core-synch-l1-2-0.dll` and `dxgi.dll` files beside the application. This is evidence that Windows 7 lacks the API-set DLL used by newer native binaries.

3. PE inspection of the previously built Windows 7 artifact showed `almoktaber.exe` is PE32+ x64 with OS/subsystem version 6.0, but `libisar.dll` imports `api-ms-win-core-synch-l1-2-0.dll` functions `WaitOnAddress`, `WakeByAddressAll`, and `WakeByAddressSingle`. This is the most likely cause of the generic Windows 7 launch rejection on the user's confirmed Windows 7 SP1 x64 system.
