FROM golang:1.19.4 as builder

WORKDIR /go/src/app
COPY src .
RUN CGO_ENABLED=0 go build -o bin .

FROM alpine:latest as certs
RUN apk --update add ca-certificates

FROM scratch
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /go/src/app/bin /bin

ENTRYPOINT ["/bin"]
