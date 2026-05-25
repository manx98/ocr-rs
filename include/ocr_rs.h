#ifndef OCR_RS_H
#define OCR_RS_H

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque OCR engine handle. */
typedef struct OcrEngine OcrEngine;

/* Inference backend identifiers. Match ocr_rs::Backend. */
typedef enum {
    OCRRS_BACKEND_CPU    = 0,
    OCRRS_BACKEND_METAL  = 1,
    OCRRS_BACKEND_OPENCL = 2,
    OCRRS_BACKEND_OPENGL = 3,
    OCRRS_BACKEND_VULKAN = 4,
    OCRRS_BACKEND_CUDA   = 5,
    OCRRS_BACKEND_COREML = 6
} ocrrs_backend_t;

/*
 * Error convention used by this ABI:
 *   - Every fallible entry point returns a `char *` that is NULL on success
 *     and points to an owned, NUL-terminated error string on failure.
 *   - The error string must be released by the caller via ocrrs_free_string.
 *   - Output values are written through `**_out` pointers and only valid
 *     on success.
 *
 * No global "last error" state is kept; the API is fully thread-safe.
 */

/* Create an OCR engine from three model/charset file paths plus a backend.
 *
 * On success returns NULL and writes the new handle to *engine_out.
 * On failure returns an owned error string; *engine_out is left unchanged.
 */
char *ocrrs_create(const char *det_path,
                   const char *rec_path,
                   const char *charset_path,
                   int backend,
                   OcrEngine **engine_out);

/* Destroy an engine. Safe to call with NULL. */
void ocrrs_destroy(OcrEngine *engine);

/* Run OCR on the file at image_path.
 *
 * On success returns NULL and writes an owned, NUL-terminated JSON string
 * to *json_out (caller frees it with ocrrs_free_string).
 * On failure returns an owned error string; *json_out is left unchanged.
 */
char *ocrrs_recognize_json(OcrEngine *engine,
                           const char *image_path,
                           char **json_out);

/* Free a string returned by this library (either an error message or a JSON
 * output buffer). Safe to call with NULL. */
void ocrrs_free_string(char *s);

/* Library version, static NUL-terminated string. */
const char *ocrrs_version(void);

#ifdef __cplusplus
}
#endif

#endif /* OCR_RS_H */
