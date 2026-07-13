FROM golang:1.26-alpine AS build

WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/llama-queue .

FROM scratch
COPY --from=build /out/llama-queue /llama-queue
EXPOSE 8080
USER 65532:65532
ENTRYPOINT ["/llama-queue"]
