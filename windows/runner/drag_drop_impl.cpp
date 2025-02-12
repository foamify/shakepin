#include "drag_drop_impl.h"
#include <shlobj.h>

ShellDataObject::ShellDataObject(const std::vector<std::wstring>& filePaths)
    : m_refCount(1), m_filePaths(filePaths) {}

ShellDataObject::~ShellDataObject() {}

HRESULT STDMETHODCALLTYPE ShellDataObject::QueryInterface(REFIID riid, void** ppvObject) {
    if (!ppvObject) return E_INVALIDARG;
    
    if (riid == IID_IUnknown || riid == IID_IDataObject) {
        *ppvObject = static_cast<IDataObject*>(this);
        AddRef();
        return S_OK;
    }
    
    *ppvObject = nullptr;
    return E_NOINTERFACE;
}

ULONG STDMETHODCALLTYPE ShellDataObject::AddRef(void) {
    return InterlockedIncrement(&m_refCount);
}

ULONG STDMETHODCALLTYPE ShellDataObject::Release(void) {
    LONG count = InterlockedDecrement(&m_refCount);
    if (count == 0) {
        delete this;
    }
    return count;
}

HRESULT STDMETHODCALLTYPE ShellDataObject::GetData(FORMATETC* pformatetc, STGMEDIUM* pmedium) {
    if (!pformatetc || !pmedium) return E_INVALIDARG;

    if (pformatetc->cfFormat == CF_HDROP && pformatetc->tymed & TYMED_HGLOBAL) {
        size_t totalSize = sizeof(DROPFILES) + sizeof(WCHAR);
        for (const auto& path : m_filePaths) {
            totalSize += (path.length() + 1) * sizeof(WCHAR);
        }

        HGLOBAL hGlobal = GlobalAlloc(GHND, totalSize);
        if (!hGlobal) return E_OUTOFMEMORY;

        DROPFILES* df = (DROPFILES*)GlobalLock(hGlobal);
        if (!df) {
            GlobalFree(hGlobal);
            return E_OUTOFMEMORY;
        }

        df->pFiles = sizeof(DROPFILES);
        df->fWide = TRUE;

        WCHAR* pFilePath = (WCHAR*)(df + 1);
        for (const auto& path : m_filePaths) {
            wcscpy_s(pFilePath, path.length() + 1, path.c_str());
            pFilePath += path.length() + 1;
        }
        *pFilePath = L'\0';  // Double null termination

        GlobalUnlock(hGlobal);

        pmedium->tymed = TYMED_HGLOBAL;
        pmedium->hGlobal = hGlobal;
        pmedium->pUnkForRelease = nullptr;

        return S_OK;
    }

    return DV_E_FORMATETC;
}

// Other IDataObject methods implementation
HRESULT STDMETHODCALLTYPE ShellDataObject::GetDataHere(FORMATETC* pformatetc, STGMEDIUM* pmedium) {
    return E_NOTIMPL;
}

HRESULT STDMETHODCALLTYPE ShellDataObject::QueryGetData(FORMATETC* pformatetc) {
    if (!pformatetc) return E_INVALIDARG;
    if (pformatetc->cfFormat == CF_HDROP && (pformatetc->tymed & TYMED_HGLOBAL))
        return S_OK;
    return DV_E_FORMATETC;
}

HRESULT STDMETHODCALLTYPE ShellDataObject::GetCanonicalFormatEtc(FORMATETC* pformatectIn, FORMATETC* pformatetcOut) {
    return E_NOTIMPL;
}

HRESULT STDMETHODCALLTYPE ShellDataObject::SetData(FORMATETC* pformatetc, STGMEDIUM* pmedium, BOOL fRelease) {
    return E_NOTIMPL;
}

HRESULT STDMETHODCALLTYPE ShellDataObject::EnumFormatEtc(DWORD dwDirection, IEnumFORMATETC** ppenumFormatEtc) {
    return E_NOTIMPL;
}

HRESULT STDMETHODCALLTYPE ShellDataObject::DAdvise(FORMATETC* pformatetc, DWORD advf, IAdviseSink* pAdvSink, DWORD* pdwConnection) {
    return OLE_E_ADVISENOTSUPPORTED;
}

HRESULT STDMETHODCALLTYPE ShellDataObject::DUnadvise(DWORD dwConnection) {
    return OLE_E_ADVISENOTSUPPORTED;
}

HRESULT STDMETHODCALLTYPE ShellDataObject::EnumDAdvise(IEnumSTATDATA** ppenumAdvise) {
    return OLE_E_ADVISENOTSUPPORTED;
}
