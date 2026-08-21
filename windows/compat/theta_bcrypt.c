#include <windows.h>

/*
 * Windows 10 exposes ProcessPrng from bcryptprimitives.dll, but Windows 7
 * does not. Isar only needs a buffer of random bytes, so use the legacy
 * system RNG API that is available on Windows 7 instead.
 */
__declspec(dllimport) BOOLEAN WINAPI SystemFunction036(PVOID buffer, ULONG length);

__declspec(dllexport) BOOL WINAPI ProcessPrng(PBYTE buffer, SIZE_T length) {
    if (length == 0) {
        return TRUE;
    }
    if (buffer == NULL || length > 0xFFFFFFFFu) {
        return FALSE;
    }
    return SystemFunction036((PVOID)buffer, (ULONG)length) ? TRUE : FALSE;
}

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved) {
    (void)instance;
    (void)reason;
    (void)reserved;
    return TRUE;
}
