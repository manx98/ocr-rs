//! Minimal C ABI shim around the `ocr-rs` crate (v2.2.x).
//!
//! Error convention: every fallible entry point returns a `*mut c_char` that
//! is NULL on success and an owned error string on failure. Output values
//! travel through `*mut *mut T` out-parameters. No global error state.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::ptr;
use std::slice;

use image::DynamicImage;
use ocr_rs::{Backend, OcrEngine, OcrEngineConfig};
use serde::Serialize;

#[derive(Serialize)]
struct JsonBBox {
    left: i32,
    top: i32,
    width: u32,
    height: u32,
}

#[derive(Serialize)]
struct JsonItem {
    text: String,
    confidence: f32,
    bbox: JsonBBox,
}

#[derive(Serialize)]
struct JsonOutput {
    results: Vec<JsonItem>,
}

/// Allocate an owned C string carrying `msg`. Returns NULL only if `msg`
/// contains an embedded NUL byte (which we never produce internally).
fn err_to_cstr(msg: impl Into<String>) -> *mut c_char {
    match CString::new(msg.into()) {
        Ok(c) => c.into_raw(),
        Err(_) => CString::new("error contained NUL")
            .expect("static literal")
            .into_raw(),
    }
}

fn map_backend(b: c_int) -> Option<Backend> {
    match b {
        0 => Some(Backend::CPU),
        1 => Some(Backend::Metal),
        2 => Some(Backend::OpenCL),
        3 => Some(Backend::OpenGL),
        4 => Some(Backend::Vulkan),
        5 => Some(Backend::CUDA),
        6 => Some(Backend::CoreML),
        _ => None,
    }
}

unsafe fn cstr_to_str<'a>(p: *const c_char, name: &str) -> Result<&'a str, String> {
    if p.is_null() {
        return Err(format!("{} is null", name));
    }
    CStr::from_ptr(p)
        .to_str()
        .map_err(|_| format!("{} is not valid UTF-8", name))
}

/// Create an OCR engine.
///
/// On success returns NULL and writes the engine handle to `*engine_out`.
/// On failure returns an owned error string; `engine_out` is untouched.
///
/// # Safety
/// All path arguments must be valid NUL-terminated C strings; `engine_out`
/// must be a non-null pointer to writable memory.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_create(
    det_path: *const c_char,
    rec_path: *const c_char,
    charset_path: *const c_char,
    backend: c_int,
    engine_out: *mut *mut OcrEngine,
) -> *mut c_char {
    if engine_out.is_null() {
        return err_to_cstr("engine_out is null");
    }

    let det = match cstr_to_str(det_path, "det_path") {
        Ok(s) => s,
        Err(e) => return err_to_cstr(e),
    };
    let rec = match cstr_to_str(rec_path, "rec_path") {
        Ok(s) => s,
        Err(e) => return err_to_cstr(e),
    };
    let charset = match cstr_to_str(charset_path, "charset_path") {
        Ok(s) => s,
        Err(e) => return err_to_cstr(e),
    };

    let backend = match map_backend(backend) {
        Some(b) => b,
        None => return err_to_cstr(format!("unknown backend id: {}", backend)),
    };

    let config = OcrEngineConfig::new().with_backend(backend);

    match OcrEngine::new(det, rec, charset, Some(config)) {
        Ok(e) => {
            *engine_out = Box::into_raw(Box::new(e));
            ptr::null_mut()
        }
        Err(e) => err_to_cstr(format!("engine init failed: {}", e)),
    }
}

/// Free an engine returned by `ocrrs_create`. Safe to call with NULL.
///
/// # Safety
/// `engine` must be either NULL or a pointer previously returned via
/// `ocrrs_create`'s out-parameter.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_destroy(engine: *mut OcrEngine) {
    if !engine.is_null() {
        drop(Box::from_raw(engine));
    }
}

/// Common pipeline: run OCR on `image`, serialize results to JSON, write
/// the owned C string through `json_out`. Returns NULL on success or an
/// owned error string on failure.
unsafe fn recognize_and_serialize(
    engine: *mut OcrEngine,
    image: DynamicImage,
    json_out: *mut *mut c_char,
) -> *mut c_char {
    let engine_ref: &OcrEngine = &*engine;
    let results = match engine_ref.recognize(&image) {
        Ok(r) => r,
        Err(e) => return err_to_cstr(format!("recognize failed: {}", e)),
    };

    let items: Vec<JsonItem> = results
        .into_iter()
        .map(|r| JsonItem {
            text: r.text,
            confidence: r.confidence,
            bbox: JsonBBox {
                left: r.bbox.rect.left(),
                top: r.bbox.rect.top(),
                width: r.bbox.rect.width(),
                height: r.bbox.rect.height(),
            },
        })
        .collect();

    let out = JsonOutput { results: items };
    let s = match serde_json::to_string(&out) {
        Ok(s) => s,
        Err(e) => return err_to_cstr(format!("json serialization failed: {}", e)),
    };

    match CString::new(s) {
        Ok(c) => {
            *json_out = c.into_raw();
            ptr::null_mut()
        }
        Err(_) => err_to_cstr("output contained NUL byte"),
    }
}

/// Run OCR on the image file at `image_path`.
///
/// On success returns NULL and writes an owned JSON string to `*json_out`;
/// caller frees it with `ocrrs_free_string`. On failure returns an owned
/// error string; `json_out` is untouched.
///
/// JSON shape:
/// ```json
/// {"results": [
///   {"text": "...", "confidence": 0.93,
///    "bbox": {"left": 12, "top": 34, "width": 100, "height": 24}}
/// ]}
/// ```
///
/// # Safety
/// `engine` must be a live pointer from `ocrrs_create`; `image_path` must be
/// a valid C string; `json_out` must be a non-null pointer to writable memory.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_recognize_json(
    engine: *mut OcrEngine,
    image_path: *const c_char,
    json_out: *mut *mut c_char,
) -> *mut c_char {
    if engine.is_null() {
        return err_to_cstr("engine is null");
    }
    if json_out.is_null() {
        return err_to_cstr("json_out is null");
    }
    let path = match cstr_to_str(image_path, "image_path") {
        Ok(s) => s,
        Err(e) => return err_to_cstr(e),
    };

    let image = match image::open(path) {
        Ok(img) => img,
        Err(e) => return err_to_cstr(format!("failed to open image: {}", e)),
    };

    recognize_and_serialize(engine, image, json_out)
}

/// Run OCR on an in-memory encoded image (PNG / JPEG / WebP / BMP / TIFF /
/// ICO / ... whatever the `image` crate's `load_from_memory` recognises by
/// magic bytes).
///
/// `data` may be NULL only when `len == 0`. The result schema, the
/// success/failure protocol, and the `json_out` ownership model are
/// identical to `ocrrs_recognize_json`.
///
/// # Safety
/// `engine` must be a live pointer from `ocrrs_create`; `data` must point
/// to at least `len` readable bytes (or be NULL with `len == 0`);
/// `json_out` must be a non-null pointer to writable memory.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_recognize_json_bytes(
    engine: *mut OcrEngine,
    data: *const u8,
    len: usize,
    json_out: *mut *mut c_char,
) -> *mut c_char {
    if engine.is_null() {
        return err_to_cstr("engine is null");
    }
    if json_out.is_null() {
        return err_to_cstr("json_out is null");
    }
    if data.is_null() && len != 0 {
        return err_to_cstr("data is null but len != 0");
    }
    if len == 0 {
        return err_to_cstr("data is empty");
    }

    let bytes = slice::from_raw_parts(data, len);
    let image = match image::load_from_memory(bytes) {
        Ok(img) => img,
        Err(e) => return err_to_cstr(format!("failed to decode image: {}", e)),
    };

    recognize_and_serialize(engine, image, json_out)
}

/// Free a string previously returned by this library (either error or JSON).
///
/// # Safety
/// `s` must be NULL or a pointer returned by this library.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

/// Library version (CARGO_PKG_VERSION), static NUL-terminated string.
#[no_mangle]
pub extern "C" fn ocrrs_version() -> *const c_char {
    static V: &str = concat!(env!("CARGO_PKG_VERSION"), "\0");
    V.as_ptr() as *const c_char
}
