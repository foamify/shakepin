#pragma once
#include <windows.h>
#include <shobjidl.h>
#include <vector>
#include <string>

class ShellDataObject : public IDataObject {
public:
    ShellDataObject(const std::vector<std::wstring>& filePaths);
    virtual ~ShellDataObject();

    // IUnknown methods
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppvObject) override;
    ULONG STDMETHODCALLTYPE AddRef(void) override;
    ULONG STDMETHODCALLTYPE Release(void) override;

    // IDataObject methods
    HRESULT STDMETHODCALLTYPE GetData(FORMATETC* pformatetc, STGMEDIUM* pmedium) override;
    HRESULT STDMETHODCALLTYPE GetDataHere(FORMATETC* pformatetc, STGMEDIUM* pmedium) override;
    HRESULT STDMETHODCALLTYPE QueryGetData(FORMATETC* pformatetc) override;
    HRESULT STDMETHODCALLTYPE GetCanonicalFormatEtc(FORMATETC* pformatectIn, FORMATETC* pformatetcOut) override;
    HRESULT STDMETHODCALLTYPE SetData(FORMATETC* pformatetc, STGMEDIUM* pmedium, BOOL fRelease) override;
    HRESULT STDMETHODCALLTYPE EnumFormatEtc(DWORD dwDirection, IEnumFORMATETC** ppenumFormatEtc) override;
    HRESULT STDMETHODCALLTYPE DAdvise(FORMATETC* pformatetc, DWORD advf, IAdviseSink* pAdvSink, DWORD* pdwConnection) override;
    HRESULT STDMETHODCALLTYPE DUnadvise(DWORD dwConnection) override;
    HRESULT STDMETHODCALLTYPE EnumDAdvise(IEnumSTATDATA** ppenumAdvise) override;

private:
    LONG m_refCount;
    std::vector<std::wstring> m_filePaths;
};
