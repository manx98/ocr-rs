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

/* Create an OCR engine from three model/charset file paths plus a backend.
   Returns NULL on failure; call ocrrs_last_error() for details. */
OcrEngine *ocrrs_create(const char *det_path,
                        const char *rec_path,
                        const char *charset_path,
                        int backend);

/* Destroy an engine. Safe to call with NULL. */
void ocrrs_destroy(OcrEngine *engine);

/* Run OCR on the file at image_path and return an owned, NUL-terminated JSON
   string. Returns NULL on failure. The caller must free the returned pointer
   with ocrrs_free_string. */
char *ocrrs_recognize_json(OcrEngine *engine, const char *image_path);

/* Free a string returned by this library. Safe to call with NULL. */
void ocrrs_free_string(char *s);

/* Return a pointer to the last error message (process-global), or NULL.
   The pointer is valid until the next call that updates the global error
   state. */
const char *ocrrs_last_error(void);

/* Library version, static NUL-terminated string. */
const char *ocrrs_version(void);

#ifdef __cplusplus
}
#endif

#endif /* OCR_RS_H */
