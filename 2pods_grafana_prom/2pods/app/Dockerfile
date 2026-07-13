FROM golang:1.26-alpine AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" -o /out/web .

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/web /web

EXPOSE 8080
USER 65532:65532
ENTRYPOINT ["/web"]
