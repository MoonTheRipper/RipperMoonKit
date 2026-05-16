/*
 * GameInput.dll stub for Wine/GPTK
 *
 * GoWR and other titles delay-load GameInput.dll (Microsoft GameInput API).
 * Wine has no builtin for it; the missing DLL raises exception 0xc06d007e
 * before any window appears. This stub exports GameInputCreate at ordinal 1
 * and returns HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) so the caller falls
 * back gracefully instead of crashing.
 *
 * Build:
 *   x86_64-w64-mingw32-gcc -nostdlib -shared -o GameInput.dll \
 *     gameinput.c gameinput.def -lkernel32
 */

#include <windows.h>

__declspec(dllexport) HRESULT __stdcall GameInputCreate(void **ppGameInput)
{
    if (ppGameInput) *ppGameInput = NULL;
    /* HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED) */
    return (HRESULT)0x80070032;
}

BOOL WINAPI DllMainCRTStartup(HINSTANCE hInst, DWORD fdwReason, LPVOID lpvReserved)
{
    return TRUE;
}
