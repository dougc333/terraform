FROM node:22-alpine AS frontend

WORKDIR /src/ui

COPY ui/package.json ui/package-lock.json ./
RUN npm ci

COPY ui/ ./
RUN npm run build

FROM golang:1.26-alpine AS build

WORKDIR /src

# Download dependencies only when go.mod or go.sum changes.
COPY go.mod go.sum ./
RUN go mod download

# Copy the application source.
COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux \
    go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/web .

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/web /web
COPY --from=frontend /src/ui/dist /ui

EXPOSE 8080
USER 65532:65532
ENTRYPOINT ["/web"]
