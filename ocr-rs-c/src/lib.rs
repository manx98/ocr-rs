//! Minimal C ABI shim around the `ocr-rs` crate (v2.2.x).
//!
//! Exposes just enough surface for the Go bindings:
//!   * `ocrrs_create`            — build an `OcrEngine` with a chosen backend
//!   * `ocrrs_destroy`           — free an engine
//!   * `ocrrs_recognize_json`    — run OCR on a file path, return a JSON string
//!   * `ocrrs_free_string`       — free a string returned by this library
//!   * `ocrrs_last_error`        — fetch the last error message
//!   * `ocrrs_version`           — return the library version

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::ptr;
use std::sync::Mutex;

use once_cell::sync::Lazy;
use ocr_rs::{Backend, OcrEngine, OcrEngineConfig};
use serde::Serialize;

static LAST_ERROR: Lazy<Mutex<Option<CString>>> = Lazy::new(|| Mutex::new(None));

fn set_last_error(msg: impl Into<String>) {
    let raw = msg.into();
    let c = CString::new(raw).unwrap_or_else(|_| CString::new("error contained NUL").unwrap());
    if let Ok(mut g) = LAST_ERROR.lock() {
        *g = Some(c);
    }
}

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

/// Create an OCR engine. Returns NULL on failure; call `ocrrs_last_error()` for details.
///
/// # Safety
/// All path arguments must be valid NUL-terminated C strings.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_create(
    det_path: *const c_char,
    rec_path: *const c_char,
    charset_path: *const c_char,
    backend: c_int,
) -> *mut OcrEngine {
    let det = match cstr_to_str(det_path, "det_path") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(e);
            return ptr::null_mut();
        }
    };
    let rec = match cstr_to_str(rec_path, "rec_path") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(e);
            return ptr::null_mut();
        }
    };
    let charset = match cstr_to_str(charset_path, "charset_path") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(e);
            return ptr::null_mut();
        }
    };

    let backend = match map_backend(backend) {
        Some(b) => b,
        None => {
            set_last_error(format!("unknown backend id: {}", backend));
            return ptr::null_mut();
        }
    };

    let config = OcrEngineConfig::new().with_backend(backend);

    match OcrEngine::new(det, rec, charset, Some(config)) {
        Ok(e) => Box::into_raw(Box::new(e)),
        Err(e) => {
            set_last_error(format!("engine init failed: {}", e));
            ptr::null_mut()
        }
    }
}

/// Free an engine returned by `ocrrs_create`. Safe to call with NULL.
///
/// # Safety
/// `engine` must be either NULL or a pointer previously returned by `ocrrs_create`.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_destroy(engine: *mut OcrEngine) {
    if !engine.is_null() {
        drop(Box::from_raw(engine));
    }
}

/// Run OCR on the image at `image_path` and return a JSON string.
///
/// JSON shape:
/// ```json
/// {"results": [
///   {"text": "...", "confidence": 0.93,
///    "bbox": {"left": 12, "top": 34, "width": 100, "height": 24}}
/// ]}
/// ```
///
/// Returns NULL on failure; call `ocrrs_last_error()` for details.
/// The returned pointer must be freed with `ocrrs_free_string`.
///
/// # Safety
/// `engine` must be a live pointer from `ocrrs_create`; `image_path` must be a valid C string.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_recognize_json(
    engine: *mut OcrEngine,
    image_path: *const c_char,
) -> *mut c_char {
    if engine.is_null() {
        set_last_error("engine is null");
        return ptr::null_mut();
    }
    let path = match cstr_to_str(image_path, "image_path") {
        Ok(s) => s,
        Err(e) => {
            set_last_error(e);
            return ptr::null_mut();
        }
    };

    let image = match image::open(path) {
        Ok(img) => img,
        Err(e) => {
            set_last_error(format!("failed to open image: {}", e));
            return ptr::null_mut();
        }
    };

    let engine_ref: &OcrEngine = &*engine;
    let results = match engine_ref.recognize(&image) {
        Ok(r) => r,
        Err(e) => {
            set_last_error(format!("recognize failed: {}", e));
            return ptr::null_mut();
        }
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
        Err(e) => {
            set_last_error(format!("json serialization failed: {}", e));
            return ptr::null_mut();
        }
    };

    match CString::new(s) {
        Ok(c) => c.into_raw(),
        Err(_) => {
            set_last_error("output contained NUL byte");
            ptr::null_mut()
        }
    }
}

/// Free a string previously returned by this library.
///
/// # Safety
/// `s` must be NULL or a pointer returned by `ocrrs_recognize_json`.
#[no_mangle]
pub unsafe extern "C" fn ocrrs_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

/// Pointer to a NUL-terminated message describing the last error, or NULL.
/// Lifetime: valid until the next call that updates the global error state.
#[no_mangle]
pub extern "C" fn ocrrs_last_error() -> *const c_char {
    match LAST_ERROR.lock() {
        Ok(g) => match g.as_ref() {
            Some(c) => c.as_ptr(),
            None => ptr::null(),
        },
        Err(_) => ptr::null(),
    }
}

/// Library version (CARGO_PKG_VERSION), static NUL-terminated string.
#[no_mangle]
pub extern "C" fn ocrrs_version() -> *const c_char {
    static V: &str = concat!(env!("CARGO_PKG_VERSION"), "\0");
    V.as_ptr() as *const c_char
}
