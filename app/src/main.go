package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "text/html")
        fmt.Fprint(w, `<html><body><h1 style="color:green;">version2</h1></body></html>`)
    })

    http.ListenAndServe(":8080", nil)
}
