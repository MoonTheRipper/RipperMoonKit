/*
 * dsound no-capture proxy
 *
 * Rebuilds the behavior of the lost gptk-dsound-nocap runner without patching
 * Apple's shipped Wine binaries. Installed as `dsound.dll` inside a runner copy
 * of the GPTK Wine home; the original builtin is renamed to `dsound_real.dll`
 * beside it (see dsound.def for the export/forward table).
 *
 * Goal: no DirectSound *capture* device is ever created, so Steam Voice cannot
 * enter the capture-lock stall that froze the ERSC Golden Pot lobby. Playback
 * is forwarded to dsound_real untouched, so game audio keeps working.
 *
 * Capture can be created two ways, and BOTH must fail (the original 2026-05-13
 * fix covered both by patching the internal DSOUND_CaptureCreate):
 *   1. Flat API: DirectSoundCaptureCreate / DirectSoundCaptureCreate8.
 *   2. COM:      CoCreateInstance(CLSID_DirectSoundCapture[8]) ->
 *                DllGetClassObject -> IClassFactory::CreateInstance.
 * Steam uses the COM path, so forwarding DllGetClassObject (as the first build
 * did) let the real capture device get created and the freeze returned.
 *
 * Here the flat functions return DSERR_NODRIVER, and DllGetClassObject hands
 * back our own IClassFactory for the capture CLSIDs whose CreateInstance also
 * returns DSERR_NODRIVER. Every other CLSID is forwarded to dsound_real so
 * playback COM objects still come from the real implementation.
 *
 * Built with mingw-w64 for x86_64 and i386, -nostdlib (no CRT imports). The COM
 * interfaces are hand-rolled to keep the build header-light; the struct layout
 * is the standard COM ABI (a pointer to a vtable of __stdcall methods).
 */

#include <windows.h>

#define DSOUND_NODRIVER            ((HRESULT)0x88780078L) /* DSERR_NODRIVER */
#define DSOUND_CLASSNOTAVAILABLE   ((HRESULT)0x80040111L) /* CLASS_E_CLASSNOTAVAILABLE */
#define DSOUND_S_FALSE             ((HRESULT)0x00000001L)
#define DSOUND_E_NOINTERFACE       ((HRESULT)0x80004002L)

static int guid_eq(const GUID *a, const GUID *b)
{
    const unsigned int *x = (const unsigned int *)a;
    const unsigned int *y = (const unsigned int *)b;
    return x[0] == y[0] && x[1] == y[1] && x[2] == y[2] && x[3] == y[3];
}

static const GUID CLSID_DSCapture  =
    {0xb0210780,0x89cd,0x11d0,{0xaf,0x08,0x00,0xa0,0xc9,0x25,0xcd,0x16}};
static const GUID CLSID_DSCapture8 =
    {0xe4bcac13,0x7f99,0x4908,{0x9a,0x8e,0x74,0xe3,0xbf,0x24,0xb6,0xe1}};
static const GUID IID_IUnknown_x =
    {0x00000000,0x0000,0x0000,{0xc0,0x00,0x00,0x00,0x00,0x00,0x00,0x46}};
static const GUID IID_IClassFactory_x =
    {0x00000001,0x0000,0x0000,{0xc0,0x00,0x00,0x00,0x00,0x00,0x00,0x46}};

/* ---- flat API: defense in depth ---- */

HRESULT __stdcall DirectSoundCaptureCreate(const GUID *device, void **out, void *outer)
{ (void)device; (void)outer; if (out) *out = NULL; return DSOUND_NODRIVER; }

HRESULT __stdcall DirectSoundCaptureCreate8(const GUID *device, void **out, void *outer)
{ (void)device; (void)outer; if (out) *out = NULL; return DSOUND_NODRIVER; }

/* ---- minimal IClassFactory whose CreateInstance always fails ---- */

struct NoCapFac;
typedef struct {
    HRESULT (__stdcall *QueryInterface)(struct NoCapFac *, const GUID *, void **);
    ULONG   (__stdcall *AddRef)(struct NoCapFac *);
    ULONG   (__stdcall *Release)(struct NoCapFac *);
    HRESULT (__stdcall *CreateInstance)(struct NoCapFac *, void *, const GUID *, void **);
    HRESULT (__stdcall *LockServer)(struct NoCapFac *, BOOL);
} NoCapFacVtbl;
typedef struct NoCapFac { const NoCapFacVtbl *lpVtbl; } NoCapFac;

static HRESULT __stdcall fac_QueryInterface(NoCapFac *self, const GUID *riid, void **ppv)
{
    if (!ppv) return E_POINTER;
    if (guid_eq(riid, &IID_IUnknown_x) || guid_eq(riid, &IID_IClassFactory_x)) {
        *ppv = self;
        return S_OK;
    }
    *ppv = NULL;
    return DSOUND_E_NOINTERFACE;
}
static ULONG __stdcall fac_AddRef(NoCapFac *self)  { (void)self; return 1; }
static ULONG __stdcall fac_Release(NoCapFac *self) { (void)self; return 1; }
static HRESULT __stdcall fac_CreateInstance(NoCapFac *self, void *outer, const GUID *riid, void **ppv)
{ (void)self; (void)outer; (void)riid; if (ppv) *ppv = NULL; return DSOUND_NODRIVER; }
static HRESULT __stdcall fac_LockServer(NoCapFac *self, BOOL lock)
{ (void)self; (void)lock; return S_OK; }

static const NoCapFacVtbl g_facVtbl = {
    fac_QueryInterface, fac_AddRef, fac_Release, fac_CreateInstance, fac_LockServer
};
static NoCapFac g_fac = { &g_facVtbl };

/* ---- COM entry points ---- */

typedef HRESULT (__stdcall *DllGetClassObject_fn)(const GUID *, const GUID *, void **);

HRESULT __stdcall DllGetClassObject(const GUID *rclsid, const GUID *riid, void **ppv)
{
    if (guid_eq(rclsid, &CLSID_DSCapture) || guid_eq(rclsid, &CLSID_DSCapture8))
        return fac_QueryInterface(&g_fac, riid, ppv);

    /* Forward every non-capture class (playback, full duplex) to the real DLL. */
    HMODULE real = LoadLibraryW(L"dsound_real.dll");
    if (real) {
        DllGetClassObject_fn fn =
            (DllGetClassObject_fn)GetProcAddress(real, "DllGetClassObject");
        if (fn) return fn(rclsid, riid, ppv);
    }
    if (ppv) *ppv = NULL;
    return DSOUND_CLASSNOTAVAILABLE;
}

/* Keep the proxy resident; capture creation never leaves live objects and the
 * real DLL owns its own playback objects. */
HRESULT __stdcall DllCanUnloadNow(void) { return DSOUND_S_FALSE; }

BOOL WINAPI DllMainCRTStartup(HINSTANCE inst, DWORD reason, LPVOID reserved)
{ (void)inst; (void)reason; (void)reserved; return TRUE; }
