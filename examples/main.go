// Example: run OCR on an image and print the JSON result.
//
//	go run ./examples \
//	    models/ch_PP-OCRv5_mobile_det.mnn \
//	    models/ch_PP-OCRv5_mobile_rec.mnn \
//	    models/ppocr_keys_v5.txt \
//	    image.jpg
package main

import (
	"fmt"
	"log"
	"os"

	ocrrs "github.com/manx98/ocr-rs"
)

func main() {
	if len(os.Args) < 5 {
		log.Fatalf("usage: %s <det.mnn> <rec.mnn> <keys.txt> <image>", os.Args[0])
	}
	det, rec, keys, img := os.Args[1], os.Args[2], os.Args[3], os.Args[4]

	eng, err := ocrrs.New(det, rec, keys, ocrrs.BackendCPU)
	if err != nil {
		log.Fatal(err)
	}
	defer eng.Close()

	js, err := eng.RecognizeJSON(img)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(js)
}
